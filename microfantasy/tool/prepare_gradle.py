"""Download a verified Gradle ZIP with curl before the Java wrapper runs.

The wrapper still owns extraction and execution. Its URL and checksum stay
unchanged; only its normal download cache is populated by this CI helper.
"""

import argparse
from dataclasses import dataclass
import hashlib
import os
from pathlib import Path
import re
import subprocess
import tempfile


@dataclass(frozen=True)
class GradleDistribution:
    url: str
    filename: str
    version: str
    sha256: str

    @property
    def download_urls(self):
        # Bypass services.gradle.org first, but retain it as an official fallback.
        tag = self.version if self.version.count('.') == 2 else self.version + '.0'
        direct = (
            'https://github.com/gradle/gradle-distributions/releases/download/'
            f'v{tag}/{self.filename}'
        )
        return direct, self.url

    def cache_directory(self, gradle_user_home):
        # Gradle PathAssembler uses unsigned MD5(URL), encoded in base 36.
        # This is a cache key, not the integrity check (which is SHA-256).
        number = int.from_bytes(
            hashlib.md5(self.url.encode('utf-8'), usedforsecurity=False).digest(), 'big'
        )
        digits = '0123456789abcdefghijklmnopqrstuvwxyz'
        key = ''
        while number:
            number, digit = divmod(number, 36)
            key = digits[digit] + key
        return Path(gradle_user_home) / 'wrapper/dists' / self.filename[:-4] / (key or '0')


def read_distribution(properties_path):
    properties = {}
    for line in Path(properties_path).read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if not line or line.startswith(('#', '!')):
            continue
        key, separator, value = line.partition('=')
        if separator:
            properties[key.strip()] = value.strip().replace(r'\:', ':')

    expected_layout = {
        'distributionBase': 'GRADLE_USER_HOME',
        'distributionPath': 'wrapper/dists',
        'zipStoreBase': 'GRADLE_USER_HOME',
        'zipStorePath': 'wrapper/dists',
    }
    if any(properties.get(key) != value for key, value in expected_layout.items()):
        raise ValueError('Unsupported Gradle cache layout; update prepare_gradle.py first.')

    url = properties.get('distributionUrl', '')
    match = re.fullmatch(
        r'https://services\.gradle\.org/distributions/'
        r'(gradle-(\d+\.\d+(?:\.\d+)?)-(?:bin|all)\.zip)', url
    )
    if not match:
        raise ValueError('Expected a pinned, official Gradle distribution URL.')
    checksum = properties.get('distributionSha256Sum', '').lower()
    if not re.fullmatch(r'[0-9a-f]{64}', checksum):
        raise ValueError('A pinned distributionSha256Sum is required.')
    return GradleDistribution(url, match[1], match[2], checksum)


def file_sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def download_with_curl(url, destination):
    subprocess.run([
        'curl', '--fail', '--location', '--show-error', '--silent',
        '--proto', '=https', '--proto-redir', '=https',
        '--connect-timeout', '15', '--max-time', '120',
        '--retry', '2', '--retry-delay', '3', '--retry-max-time', '60',
        '--output', str(destination), url,
    ], check=True, timeout=210)


def prepare_distribution(distribution, gradle_user_home):
    directory = distribution.cache_directory(gradle_user_home)
    archive = directory / distribution.filename
    marker = directory / (distribution.filename + '.ok')
    launcher = directory / f'gradle-{distribution.version}/lib/gradle-launcher-{distribution.version}.jar'
    if marker.is_file() and launcher.is_file():
        print(f'Using installed Gradle {distribution.version} from cache.', flush=True)
        return directory
    if archive.is_file() and file_sha256(archive) == distribution.sha256:
        print(f'Using verified Gradle {distribution.version} ZIP from cache.', flush=True)
        return directory

    directory.mkdir(parents=True, exist_ok=True)
    for url in distribution.download_urls:
        with tempfile.NamedTemporaryFile(dir=directory, suffix='.download', delete=False) as stream:
            temporary = Path(stream.name)
        try:
            print(f'Downloading Gradle {distribution.version} with curl: {url}', flush=True)
            try:
                download_with_curl(url, temporary)
            except (OSError, subprocess.SubprocessError) as error:
                print(f'Download failed: {error}', flush=True)
                continue
            actual = file_sha256(temporary)
            if actual != distribution.sha256:
                raise ValueError(
                    f'Gradle SHA-256 mismatch. Expected {distribution.sha256}, got {actual}. '
                    'The downloaded file will not be used.'
                )
            # Never let the wrapper see a partial or unverified download.
            os.replace(temporary, archive)
            print(f'Gradle ZIP verified and ready for the wrapper: {archive}', flush=True)
            return directory
        finally:
            temporary.unlink(missing_ok=True)
    raise RuntimeError('Both official Gradle download routes failed. See curl errors above.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wrapper-properties', type=Path,
                        default=Path('android/gradle/wrapper/gradle-wrapper.properties'))
    parser.add_argument('--gradle-user-home', type=Path,
                        default=Path(os.environ.get('GRADLE_USER_HOME', Path.home() / '.gradle')))
    args = parser.parse_args()
    try:
        prepare_distribution(read_distribution(args.wrapper_properties), args.gradle_user_home)
    except (OSError, ValueError, RuntimeError) as error:
        print(f'::error::{error}', flush=True)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
