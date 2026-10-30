import unittest
from android_release import manifest, version_metadata


class AndroidReleaseTest(unittest.TestCase):
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
