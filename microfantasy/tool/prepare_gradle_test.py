import hashlib
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

from prepare_gradle import GradleDistribution, prepare_distribution, read_distribution


class PrepareGradleTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.cache = Path(self.temp.name)
        self.content = b'verified distribution test fixture'
        self.distribution = GradleDistribution(
            'https://services.gradle.org/distributions/gradle-9.3.1-bin.zip',
            'gradle-9.3.1-bin.zip', '9.3.1', hashlib.sha256(self.content).hexdigest(),
        )
        self.directory = self.distribution.cache_directory(self.cache)
        self.archive = self.directory / self.distribution.filename
        output = redirect_stdout(io.StringIO())
        output.__enter__()
        self.addCleanup(output.__exit__, None, None, None)

    def successful_download(self, url, destination):
        destination.write_bytes(self.content)

    def test_cache_path_matches_the_real_gradle_931_wrapper(self):
        self.assertEqual(self.directory.relative_to(self.cache).as_posix(),
                         'wrapper/dists/gradle-9.3.1-bin/23ovyewtku6u96viwx3xl3oks')

    def test_reads_repository_wrapper_version_and_checksum(self):
        path = Path(__file__).resolve().parents[1] / 'android/gradle/wrapper/gradle-wrapper.properties'
        distribution = read_distribution(path)
        self.assertEqual(distribution.version, '9.3.1')
        self.assertEqual(distribution.sha256,
                         'b266d5ff6b90eada6dc3b20cb090e3731302e553a27c5d3e4df1f0d76beaff06')

    def test_rejects_missing_checksum_and_unsupported_layout_or_url(self):
        source = Path(__file__).resolve().parents[1] / 'android/gradle/wrapper/gradle-wrapper.properties'
        text = source.read_text()
        invalid_variants = [
            '\n'.join(line for line in text.splitlines() if not line.startswith('distributionSha256Sum=')),
            text.replace('distributionBase=GRADLE_USER_HOME', 'distributionBase=PROJECT'),
            text.replace('services.gradle.org', 'untrusted.example'),
        ]
        for invalid in invalid_variants:
            with self.subTest(invalid=invalid):
                path = self.cache / 'gradle-wrapper.properties'
                path.write_text(invalid)
                with self.assertRaises(ValueError):
                    read_distribution(path)

    def test_direct_download_populates_cache_without_marking_it_installed(self):
        with patch('prepare_gradle.download_with_curl', side_effect=self.successful_download) as download:
            prepare_distribution(self.distribution, self.cache)
        self.assertEqual(self.archive.read_bytes(), self.content)
        self.assertEqual(download.call_args.args[0],
                         'https://github.com/gradle/gradle-distributions/releases/download/'
                         'v9.3.1/gradle-9.3.1-bin.zip')
        self.assertFalse(list(self.directory.glob('*.ok')))
        self.assertFalse(list(self.directory.glob('*.download')))

    def test_http_504_falls_back_to_second_official_route(self):
        def download(url, destination):
            if url.startswith('https://github.com/'):
                destination.write_bytes(b'partial download')
                raise subprocess.CalledProcessError(22, ['curl'], stderr='HTTP 504')
            self.successful_download(url, destination)

        with patch('prepare_gradle.download_with_curl', side_effect=download) as request:
            prepare_distribution(self.distribution, self.cache)
        self.assertEqual([call.args[0] for call in request.call_args_list],
                         list(self.distribution.download_urls))
        self.assertEqual(self.archive.read_bytes(), self.content)
        self.assertFalse(list(self.directory.glob('*.download')))

    def test_both_routes_fail_without_leaving_a_partial_archive(self):
        with patch('prepare_gradle.download_with_curl', side_effect=subprocess.TimeoutExpired('curl', 210)):
            with self.assertRaisesRegex(RuntimeError, 'Both official'):
                prepare_distribution(self.distribution, self.cache)
        self.assertFalse(self.archive.exists())
        self.assertFalse(list(self.directory.iterdir()))

    def test_wrong_checksum_never_becomes_a_wrapper_archive(self):
        def corrupted_download(url, destination):
            destination.write_bytes(b'invalid zip or an HTML error with HTTP 200')

        with patch('prepare_gradle.download_with_curl', side_effect=corrupted_download) as request:
            with self.assertRaisesRegex(ValueError, 'SHA-256 mismatch'):
                prepare_distribution(self.distribution, self.cache)
        self.assertEqual(request.call_count, 1)
        self.assertFalse(self.archive.exists())
        self.assertFalse(list(self.directory.iterdir()))

    def test_existing_verified_zip_does_not_use_the_network(self):
        self.directory.mkdir(parents=True)
        self.archive.write_bytes(self.content)
        with patch('prepare_gradle.download_with_curl') as download:
            prepare_distribution(self.distribution, self.cache)
        download.assert_not_called()

    def test_invalid_cached_zip_is_replaced_only_after_verification(self):
        self.directory.mkdir(parents=True)
        self.archive.write_bytes(b'broken cache')
        with patch('prepare_gradle.download_with_curl', side_effect=self.successful_download):
            prepare_distribution(self.distribution, self.cache)
        self.assertEqual(self.archive.read_bytes(), self.content)

    def test_completed_wrapper_install_is_reused_without_downloading(self):
        self.directory.mkdir(parents=True)
        (self.directory / (self.distribution.filename + '.ok')).touch()
        launcher = self.directory / 'gradle-9.3.1/lib/gradle-launcher-9.3.1.jar'
        launcher.parent.mkdir(parents=True)
        launcher.write_bytes(b'already installed by the wrapper')
        with patch('prepare_gradle.download_with_curl') as download:
            prepare_distribution(self.distribution, self.cache)
        download.assert_not_called()

    def test_incomplete_install_marker_does_not_skip_download(self):
        self.directory.mkdir(parents=True)
        (self.directory / (self.distribution.filename + '.ok')).touch()
        with patch('prepare_gradle.download_with_curl', side_effect=self.successful_download) as download:
            prepare_distribution(self.distribution, self.cache)
        download.assert_called_once()


if __name__ == '__main__':
    unittest.main()
