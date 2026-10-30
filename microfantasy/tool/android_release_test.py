import unittest
from android_release import manifest, version_metadata, verified_certificate


class AndroidReleaseTest(unittest.TestCase):
    def test_signer_formats(self):
        for prefix in ('Signer #1', 'Signer (minSdkVersion=24, maxSdkVersion=32)',
                       'V3.0 Signer:', 'V2 Signer #1:',
                       'V3.1 Signer: (minSdkVersion=33, maxSdkVersion=2147483647)'):
            with self.subTest(prefix=prefix):
                output = f'Number of signers: 1\n{prefix} certificate SHA-256 digest: ' + 'A' * 64 + '\n'
                self.assertEqual(verified_certificate(output, 'a' * 64), 'a' * 64)

    def test_same_identity_across_schemes_is_accepted(self):
        output = '\n'.join(f'{scheme} Signer: certificate SHA-256 digest: ' + 'a' * 64
                           for scheme in ('V2', 'V3.0'))
        self.assertEqual(verified_certificate(output, 'a' * 64), 'a' * 64)

    def test_stamp_and_lineage_are_not_apk_signers(self):
        for prefix in ('Source Stamp Signer:', 'Signer #1 in lineage'):
            with self.assertRaises(ValueError):
                verified_certificate(f'{prefix} certificate SHA-256 digest: ' + 'a' * 64, 'a' * 64)

    def test_wrong_missing_or_multiple_signers_are_rejected(self):
        valid = 'Signer #1 certificate SHA-256 digest: ' + 'a' * 64
        for output in ('', valid.replace('a' * 64, 'b' * 64),
                       valid + '\nSigner #2 certificate SHA-256 digest: ' + 'b' * 64,
                       'Number of signers: 2\n' + valid):
            with self.assertRaises(ValueError):
                verified_certificate(output, 'a' * 64)
        with self.assertRaises(ValueError):
            verified_certificate(valid, '')

    def test_codes_increase_even_if_workflow_counter_resets(self):
        first = version_metadata(10, 'a' * 40, 1800000000)
        later = version_metadata(1, 'b' * 40, 1800000001)
        self.assertGreater(later['code'], first['code'])
        self.assertLess(later['code'], 2100000000)

    def test_invalid_metadata_is_rejected(self):
        for run, sha, timestamp in [(0, 'a' * 40, 1800000000), (1, 'x', 1800000000), (1, 'a' * 40, 5000000000)]:
            with self.assertRaises(ValueError):
                version_metadata(run, sha, timestamp)

    def test_manifest_points_to_versioned_apk_with_verifiable_signer(self):
        meta = version_metadata(8, 'a' * 40, 1800000000)
        data = manifest(meta, 'f' * 64, 'A' * 64)
        self.assertEqual(data['certificateSha256'], 'a' * 64)
        self.assertEqual(data['versionCode'], meta['code'])
        self.assertEqual(data['apkUrl'], f"https://github.com/Asdii/V90-Fantasy-Designer/releases/download/{meta['tag']}/microfantasy.apk")
        with self.assertRaises(ValueError):
            manifest(meta, 'f' * 64, 'invalid')


if __name__ == '__main__':
    unittest.main()
