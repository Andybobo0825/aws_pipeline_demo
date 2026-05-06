import os
import unittest

from main import create_app


class AppRouteTests(unittest.TestCase):
    def setUp(self):
        os.environ["APP_ENV"] = "test"
        self.client = create_app().test_client()

    def test_index_renders_portfolio_page(self):
        response = self.client.get("/")

        self.assertEqual(response.status_code, 200)
        self.assertIn("text/html", response.content_type)
        html = response.get_data(as_text=True)
        self.assertIn("AWS DevOps 自動部署作品集", html)
        self.assertIn("test", html)
        self.assertIn("/static/styles.css", html)

    def test_health_returns_ok(self):
        response = self.client.get("/health")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json(), {"status": "ok"})


if __name__ == "__main__":
    unittest.main()
