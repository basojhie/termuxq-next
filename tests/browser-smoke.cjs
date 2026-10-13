const assert = require('node:assert/strict');
const fs = require('node:fs');
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ acceptDownloads: true });
  const pageErrors = [];
  page.on('pageerror', error => pageErrors.push(error.message));
  // Simulate an older agent: /stats works but does not advertise LAN ping support.
  await page.route('http://127.0.0.1:8765/stats', route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    headers: { 'Access-Control-Allow-Origin': 'http://127.0.0.1:8000', 'Cache-Control': 'no-store' },
    body: JSON.stringify({ host: 'legacy-agent', os: 'Test OS', cores: 4, cpu_pct: 10, mem: {pct: 20}, disk: {pct: 30}, battery: null, ip: '127.0.0.1', uptime: 100 })
  }));

  try {
    await page.goto(process.env.TERMUXQ_URL || 'http://127.0.0.1:8000', { waitUntil: 'domcontentloaded' });
    await page.locator('#mod-count').waitFor();
    assert.equal(await page.locator('#mode-banner').count(), 1, 'compact browser-mode banner should appear');
    assert.match(await page.locator('#mode-banner').innerText(), /Browser Mode.*Agent dibutuhkan untuk metrik perangkat dan ping LAN/);
    assert.doesNotMatch(await page.locator('#mode-banner').innerText(), /Modul yang bisa berjalan di browser/);
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
    await page.locator('#modal-app #lan-hosts').fill('192.168.1.10');
    await page.locator('#modal-app #lan-scan').click();
    assert.match(await page.locator('#modal-app #lan-summary').innerText(), /versinya lama|belum mendukung LAN ping/i);
    assert.equal(await page.locator('#modal-app #lan-copy-win').count(), 1);
    await page.locator('#modal-close').click();

    // Ticket form: create, update status, export.
    await page.evaluate(() => localStorage.setItem('tq_asset_inventory_v1', JSON.stringify([
      { id: 'asset-qa-1', name: 'QA Workstation', ip: '192.168.1.20', zone: 'Zona QA', type: 'PC', status: 'Belum dicek' }
    ])));
    await page.locator('[data-module="tickets"]').click();
    await page.locator('#modal-app #title').fill('Printer offline smoke test');
    await page.locator('#modal-app #asset-link').selectOption('asset-qa-1');
    assert.equal(await page.locator('#modal-app #device').inputValue(), 'QA Workstation · 192.168.1.20 · Zona QA');
    await page.locator('#modal-app #description').fill('Browser automated test');
    await page.locator('#modal-app #assignee').fill('QA Technician');
    await page.locator('#modal-app #category').selectOption('Printer');
    await page.locator('#modal-app #ticket-form button[type="submit"]').click();
    assert.match(await page.locator('#modal-app #count').innerText(), /1 tiket tersimpan/);
    await page.locator('#modal-app [data-response]').click();
    assert.ok(await page.evaluate(() => JSON.parse(localStorage.getItem('tq_tickets'))[0].firstResponseAt));
    await page.locator('#modal-app select[data-status]').selectOption('Waiting');
    assert.equal(await page.locator('#modal-app select[data-status]').inputValue(), 'Waiting');
    assert.ok(JSON.parse(await page.evaluate(() => localStorage.getItem('tq_tickets')))[0].waitingReason);
    await page.locator('#modal-app select[data-status]').selectOption('In Progress');
    assert.equal(await page.locator('#modal-app select[data-status]').inputValue(), 'In Progress');
    assert.match(await page.locator('#modal-app #list').innerText(), /QA Technician/);
    assert.match(await page.locator('#modal-app #list').innerText(), /Printer/);
    page.once('dialog', dialog => dialog.accept('Membersihkan roller, uji cetak berhasil.'));
    await page.locator('#modal-app [data-note]').click();
    const workflowTicket = await page.evaluate(() => JSON.parse(localStorage.getItem('tq_tickets'))[0]);
    assert.equal(workflowTicket.comments.length, 1);
    assert.equal(workflowTicket.comments[0].text, 'Membersihkan roller, uji cetak berhasil.');
    assert.ok(workflowTicket.statusHistory.some(entry => entry.to === 'Waiting' && entry.reason));
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.locator('#modal-app #export').click()
    ]);
    assert.match(download.suggestedFilename(), /^termuxq-tickets-.*\.json$/);
    const downloadPath = await download.path();
    const exported = JSON.parse(fs.readFileSync(downloadPath, 'utf8'));
    assert.equal(exported.tickets[0].title, 'Printer offline smoke test');
    assert.equal(exported.tickets[0].status, 'In Progress');
    assert.equal(exported.tickets[0].assetRef.id, 'asset-qa-1');
    assert.equal(exported.tickets[0].assetRef.name, 'QA Workstation');
    assert.equal(exported.tickets[0].assetRef.ip, '192.168.1.20');
    assert.match(await page.locator('#modal-app #list').innerText(), /Aset terkait: QA Workstation/);
    await page.evaluate(() => localStorage.removeItem('tq_asset_inventory_v1'));
    await page.locator('#modal-close').click();

    // IT Asset Inventory: validation, add/edit, zone filtering, and JSON export.
    await page.locator('[data-module="inventory"]').click();
    await page.locator('#modal-app #inv-name').fill('QA Workstation');
    await page.locator('#modal-app #inv-zone').fill('Zona QA');
    await page.locator('#modal-app #inv-ip').fill('8.8.8.8');
    await page.locator('#modal-app #inv-submit').click();
    assert.match(await page.locator('#modal-app #inv-message').innerText(), /IP privat RFC1918/i);
    assert.equal(await page.locator('#modal-app [data-asset]').count(), 0);
    await page.locator('#modal-app #inv-ip').fill('192.168.1.20');
    await page.locator('#modal-app #inv-type').selectOption('PC');
    await page.locator('#modal-app #inv-submit').click();
    assert.match(await page.locator('#modal-app #inv-info').innerText(), /1 perangkat tersimpan/);
    assert.match(await page.locator('#modal-app #inv-list').innerText(), /QA Workstation/);
    await page.locator('#modal-app [data-asset-edit]').click();
    await page.locator('#modal-app #inv-zone').fill('Zona 2');
    await page.locator('#modal-app #inv-submit').click();
    assert.match(await page.locator('#modal-app #inv-list').innerText(), /Zona 2/);
    await page.locator('#modal-app #inv-search').fill('not-found');
    assert.equal(await page.locator('#modal-app [data-asset]').count(), 0);
    await page.locator('#modal-app #inv-search').fill('');
    const [inventoryDownload] = await Promise.all([
      page.waitForEvent('download'),
      page.locator('#modal-app #inv-export').click()
    ]);
    assert.match(inventoryDownload.suggestedFilename(), /^termuxq-inventory-.*\.json$/);
    const inventoryPath = await inventoryDownload.path();
    const inventoryExport = JSON.parse(fs.readFileSync(inventoryPath, 'utf8'));
    assert.equal(inventoryExport.devices[0].name, 'QA Workstation');
    assert.equal(inventoryExport.devices[0].zone, 'Zona 2');
    await page.locator('#modal-close').click();

    // IT Operations Overview: summarizes asset and ticket data already stored locally.
    await page.evaluate(() => {
      const checked = new Date().toISOString();
      localStorage.setItem('tq_asset_inventory_v1', JSON.stringify([
        {id:'ops-online-1',name:'Ops Online PC',ip:'192.168.1.31',zone:'Zona 1',type:'PC',status:'Online',latencyMs:2,lastCheckedAt:checked},
        {id:'ops-no-reply-1',name:'Ops Printer',ip:'192.168.1.32',zone:'Zona 2',type:'Printer',status:'No Reply',lastCheckedAt:checked},
        {id:'ops-error-1',name:'Ops Router',ip:'192.168.1.33',zone:'Zona 2',type:'Network',status:'Error',lastCheckedAt:checked},
        {id:'ops-unchecked-1',name:'Ops Laptop',ip:'192.168.1.34',zone:'Zona 3',type:'Laptop',status:'Belum dicek'}
      ]));
      localStorage.setItem('tq_tickets', JSON.stringify([
        {id:'ops-ticket-high',title:'Periksa workstation',device:'Ops Online PC',priority:'High',status:'Open',createdAt:checked,assetRef:{id:'ops-online-1',name:'Ops Online PC',ip:'192.168.1.31',zone:'Zona 1'}},
        {id:'ops-ticket-normal',title:'Tindak lanjut printer',device:'Ops Printer',priority:'Normal',status:'In Progress',createdAt:checked},
        {id:'ops-ticket-resolved',title:'Printer selesai',device:'Ops Printer',priority:'Critical',status:'Resolved',createdAt:checked}
      ]));
    });
    await page.locator('[data-module="opsdash"]').click();
    assert.equal(await page.locator('#modal-app #ops-total-assets').innerText(), '4');
    assert.equal(await page.locator('#modal-app #ops-online').innerText(), '1');
    assert.equal(await page.locator('#modal-app #ops-no-reply').innerText(), '1');
    assert.equal(await page.locator('#modal-app #ops-not-checked').innerText(), '1');
    assert.equal(await page.locator('#modal-app #ops-error').innerText(), '1');
    assert.equal(await page.locator('#modal-app #ops-open-tickets').innerText(), '2');
    assert.equal(await page.locator('#modal-app #ops-high-priority').innerText(), '1');
    assert.equal(await page.locator('#modal-app #ops-resolved').innerText(), '1');
    assert.match(await page.locator('#modal-app #ops-ticket-list').innerText(), /Periksa workstation/);
    await page.locator('#modal-app #ops-refresh').click();
    await page.locator('#modal-close').click();

    // Cloud Sync module: Supabase SDK auth and database calls are isolated with a deterministic browser stub.
    await page.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2', route => route.fulfill({
      status: 200,
      contentType: 'application/javascript',
      body: "window.__syncMock={session:null,remote:[],uploaded:[]};\nwindow.supabase={createClient:function(){\n const mock=window.__syncMock;\n return {auth:{\n  getSession:async()=>({data:{session:mock.session},error:null}),\n  signInWithPassword:async({email,password})=>{if(!email||!password)return {data:{session:null},error:{message:'missing login'}};mock.session={access_token:'mock-session',user:{id:'11111111-2222-4333-8444-555555555555',email}};return {data:{session:mock.session,user:mock.session.user},error:null}},\n  signUp:async({email})=>({data:{session:null,user:{email}},error:null}),\n  signOut:async()=>{mock.session=null;return {error:null}}\n },from:function(){\n  const builder={select:function(){return this},eq:function(){return this},order:function(){return this},\n   range:async function(start,end){return {data:mock.remote.slice(start,end+1),error:null}},\n   upsert:async function(rows){mock.uploaded.push(...rows);for(const row of rows){const i=mock.remote.findIndex(x=>x.user_id===row.user_id&&x.record_type===row.record_type&&x.record_id===row.record_id);if(i<0)mock.remote.push(row);else mock.remote[i]=row}return {data:null,error:null}}\n  };return builder\n }};\n}};"
    }));
    await page.evaluate(() => {
      localStorage.setItem('tq_asset_inventory_v1', JSON.stringify([
        {id:'sync-asset-qa',name:'Sync QA PC',ip:'192.168.2.20',zone:'Zona QA',type:'PC',status:'Online'}
      ]));
      localStorage.setItem('tq_tickets', JSON.stringify([
        {id:'sync-ticket-qa',title:'Sync QA Ticket',device:'Sync QA PC',priority:'High',status:'Open',createdAt:new Date().toISOString()}
      ]));
    });
    await page.locator('[data-module="synccloud"]').click();
    await page.locator('#modal-app #sync-url').fill('https://termuxq-sync-test.supabase.co');
    await page.locator('#modal-app #sync-key').fill('sb_publishable_qa-test-key');
    await page.locator('#modal-app #sync-save-config').click();
    assert.match(await page.locator('#modal-app #sync-status').innerText(), /Konfigurasi disimpan/);
    await page.locator('#modal-app #sync-email').fill('qa@example.com');
    await page.locator('#modal-app #sync-password').fill('test-password-only');
    await page.locator('#modal-app #sync-login').click();
    await page.waitForFunction(() => document.querySelector('#modal-app #sync-status')?.textContent.includes('Login berhasil'));
    await page.locator('#modal-app #sync-now').click();
    await page.waitForFunction(() => document.querySelector('#modal-app #sync-status')?.textContent.includes('Sinkronisasi berhasil'), null, { timeout: 12000 });
    const mockSync = await page.evaluate(() => window.__syncMock);
    assert.ok(mockSync.uploaded.some(row => row.record_type === 'asset' && row.record_id === 'sync-asset-qa'));
    assert.ok(mockSync.uploaded.some(row => row.record_type === 'ticket' && row.record_id === 'sync-ticket-qa'));
    assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('tq_sync_baseline_v1')).assets.length), 1);
    assert.match(await page.locator('#modal-app #sync-account').innerText(), /qa@example.com/);
    await page.locator('#modal-close').click();

    // SLA monitor: test business-time targets, breach/risk counters, settings, and ticket timestamps.
    await page.evaluate(() => {
      const now = Date.now();
      localStorage.setItem('tq_sla_config_v1', JSON.stringify({
        businessStart:'00:00', businessEnd:'23:59', workDays:[0,1,2,3,4,5,6],
        targets:{
          Critical:{response:15,resolution:120},
          High:{response:30,resolution:240},
          Normal:{response:240,resolution:480},
          Low:{response:480,resolution:1440}
        }
      }));
      localStorage.setItem('tq_tickets', JSON.stringify([
        {id:'sla-late',title:'Critical SLA overdue',device:'QA Workstation',priority:'Critical',status:'Open',createdAt:new Date(now-10*86400000).toISOString(),firstResponseAt:null,resolvedAt:null},
        {id:'sla-risk',title:'Critical SLA near response deadline',device:'Ops Printer',priority:'Critical',status:'Open',createdAt:new Date(now-8*60000).toISOString(),firstResponseAt:null,resolvedAt:null},
        {id:'sla-resolved',title:'Resolved within SLA',device:'Ops Laptop',priority:'Critical',status:'Resolved',createdAt:new Date(now-45*60000).toISOString(),firstResponseAt:new Date(now-40*60000).toISOString(),resolvedAt:new Date(now-10*60000).toISOString()}
      ]));
    });
    await page.locator('[data-module="sla"]').click();
    assert.equal(await page.locator('#modal-app #sla-total-active').innerText(), '2');
    assert.equal(await page.locator('#modal-app #sla-response-late').innerText(), '1');
    assert.equal(await page.locator('#modal-app #sla-resolution-late').innerText(), '1');
    assert.equal(await page.locator('#modal-app #sla-at-risk').innerText(), '1');
    assert.equal(await page.locator('#modal-app #sla-resolved-on-time').innerText(), '1');
    assert.match(await page.locator('#modal-app #sla-list').innerText(), /Terlambat respons/);
    assert.match(await page.locator('#modal-app #sla-list').innerText(), /Penyelesaian terlambat/);
    await page.locator('#modal-app #sla-critical-response').fill('20');
    await page.locator('#modal-app #sla-save').click();
    assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('tq_sla_config_v1')).targets.Critical.response), 20);
    await page.locator('#modal-app #sla-search').fill('near response deadline');
    assert.match(await page.locator('#modal-app #sla-list').innerText(), /Critical SLA near response deadline/);
    await page.locator('#modal-close').click();

    // Audit Trail: tracks ticket status changes and asset changes; supports filtering/export.
    await page.locator('[data-module="auditlog"]').click();
    const auditText = await page.locator('#modal-app #audit-list').innerText();
    assert.match(auditText, /Ubah status|Tambah|Edit/);
    assert.match(await page.locator('#modal-app #audit-info').innerText(), /aktivitas tersimpan/);
    await page.locator('#modal-app #audit-search').fill('QA Workstation');
    assert.match(await page.locator('#modal-app #audit-list').innerText(), /QA Workstation/);
    await page.locator('#modal-app #audit-search').fill('');
    const [auditDownload] = await Promise.all([
      page.waitForEvent('download'),
      page.locator('#modal-app #audit-export').click()
    ]);
    assert.match(auditDownload.suggestedFilename(), /^termuxq-audit-.*\.json$/);
    const auditPath = await auditDownload.path();
    const auditExport = JSON.parse(fs.readFileSync(auditPath, 'utf8'));
    assert.ok(auditExport.entries.some(entry => entry.action === 'Ubah status'));
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
    assert.match(checkText, /IT Asset Inventory/);
    assert.match(checkText, /IT Operations Overview/);
    assert.match(checkText, /Cloud Sync \(Supabase\)/);
    assert.match(checkText, /Audit Trail \/ Activity Log/);
    assert.match(checkText, /SLA & Ticket Priority Monitoring/);
    assert.match(checkText, /HTTP Inspector/);

    assert.deepEqual(pageErrors, [], 'page should not emit uncaught JavaScript errors');
    console.log('PASS: dashboard, resource history, subnet, LAN validation, tickets with response/resolution timestamps, inventory, IT operations summary, cloud sync SDK flow, audit trail, SLA monitor, SHA-256, HTTP Inspector, and Project Health Check.');
  } finally {
    await browser.close();
  }
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
