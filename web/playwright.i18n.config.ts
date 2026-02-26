import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  timeout: 60000,
  expect: { timeout: 15000 },
  reporter: [["list"]],
  testMatch: /.*\/tests\/e2e\/i18n\/.*\.spec\.ts/,
  outputDir: "output/playwright",
  use: {
    baseURL: "http://localhost:3000",
    trace: "retain-on-failure",
    video: "retain-on-failure",
  },
  projects: [
    {
      name: "i18n",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
