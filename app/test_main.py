import os
import unittest

from main import create_app


class AppRouteTests(unittest.TestCase):
    def setUp(self):
        os.environ["APP_ENV"] = "test"
        self.client = create_app().test_client()

    def test_index_returns_message_and_env(self):
        response = self.client.get("/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json(), {"message": "hello from ecs", "env": "test"})

    def test_health_returns_ok(self):
        response = self.client.get("/health")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json(), {"status": "ok"})


if __name__ == "__main__":
    unittest.main()
