const assert = require('node:assert/strict');
const fs = require('node:fs');
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ acceptDownloads: true });
  const pageErrors = [];
  page.on('pageerror', error => pageErrors.push(error.message));

  try {
    await page.goto(process.env.TERMUXQ_URL || 'http://127.0.0.1:8000', { waitUntil: 'domcontentloaded' });
    await page.locator('#mod-count').waitFor();
    assert.equal(await page.locator('#tq-metric-history').count(), 1, 'resource history panel should appear');

    // Subnet calculator: common /24 sample and validation.
    await page.locator('[data-module="subnet"]').click();
    await page.locator('#cidr').fill('192.168.1.10/24');
    await page.locator('#subnet-form button[type="submit"]').click();
    let result = await page.locator('#subnet-out').innerText();
    assert.match(result, /Network ID\s*:\s*192\.168\.1\.0/);
    assert.match(result, /Broadcast\s*:\s*192\.168\.1\.255/);
    assert.match(result, /Host usable\s*:\s*254/);
    await page.locator('#cidr').fill('999.1.1.1/24');
    await page.locator('#subnet-form button[type="submit"]').click();
    assert.match(await page.locator('#subnet-out').innerText(), /oktet IPv4/i);
    await page.locator('#modal-close').click();

    // LAN monitor validates target scope in the browser before contacting the agent.
    await page.locator('[data-module="lan"]').click();
    await page.locator('#modal-app #lan-hosts').fill('8.8.8.8');
    await page.locator('#modal-app #lan-scan').click();
    assert.match(await page.locator('#modal-app #lan-summary').innerText(), /RFC1918/);
    await page.locator('#modal-close').click();

    // Ticket form: create, update status, export.
    await page.locator('[data-module="tickets"]').click();
    await page.locator('#modal-app #title').fill('Printer offline smoke test');
    await page.locator('#modal-app #device').fill('Zona QA');
    await page.locator('#modal-app #description').fill('Browser automated test');
    await page.locator('#modal-app #ticket-form button[type="submit"]').click();
    assert.match(await page.locator('#modal-app #count').innerText(), /1 tiket tersimpan/);
    await page.locator('#modal-app select[data-status]').selectOption('In Progress');
    assert.equal(await page.locator('#modal-app select[data-status]').inputValue(), 'In Progress');
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.locator('#modal-app #export').click()
    ]);
    assert.match(download.suggestedFilename(), /^termuxq-tickets-.*\.json$/);
    const downloadPath = await download.path();
    const exported = JSON.parse(fs.readFileSync(downloadPath, 'utf8'));
    assert.equal(exported.tickets[0].title, 'Printer offline smoke test');
    assert.equal(exported.tickets[0].status, 'In Progress');
    await page.locator('#modal-close').click();

    // Hashing: SHA-256 of known string.
    await page.locator('[data-module="hash"]').click();
    await page.locator('#modal-app #t').fill('abc');
    await page.waitForFunction(() => document.querySelector('#modal-app #o')?.textContent.includes('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'));
    await page.locator('#modal-close').click();

    // Network inspector UI should load without making an unsolicited outbound test.
    await page.locator('[data-module="http"]').click();
    assert.equal(await page.locator('#modal-app #http-form').count(), 1);
    assert.equal(await page.locator('#modal-app #http-url').inputValue(), 'https://example.com');
    await page.locator('#modal-close').click();

    // Project Health Check completes and identifies the shipped client-side modules.
    await page.locator('[data-module="check"]').click();
    await page.waitForFunction(() => document.querySelector('#modal-app #check-summary')?.textContent.includes('Pemeriksaan selesai'), null, { timeout: 25000 });
    const checkText = await page.locator('#modal-app #check-results').innerText();
    assert.match(checkText, /IPv4 Subnet Calculator/);
    assert.match(checkText, /IT Support Ticket Log/);
    assert.match(checkText, /HTTP Inspector/);

    assert.deepEqual(pageErrors, [], 'page should not emit uncaught JavaScript errors');
    console.log('PASS: dashboard, resource-history panel, subnet calculator, LAN target validation, ticket CRUD/status/export, SHA-256, HTTP Inspector, and Project Health Check.');
  } finally {
    await browser.close();
  }
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
