const assert = require('assert');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'app.html'), 'utf8');

assert.ok(html.includes('system同步对账'), 'admin/dean summary should include a system sync reconciliation submodule');
assert.ok(html.includes('syncReconciliationRows'), 'app should compute per-project sync reconciliation rows');
assert.ok(html.includes('systemSyncCoverage'), 'app should compute system sync coverage');
assert.ok(html.includes('invalidSystemSyncScoreRows'), 'app should identify non-July or unknown-source system sync scores');
assert.ok(html.includes('clearInvalidSystemSyncScores'), 'app should provide an admin cleanup action for invalid old sync scores');
assert.ok(html.includes('teacherScoreSourceLabel'), 'teacher detail should label score source');
assert.ok(html.includes('只限 7 月'), 'excellent contribution rule should clearly say it is July-only');
assert.ok(html.includes('来源考试'), 'sync rows should expose the source exam/date context from notes');

console.log(JSON.stringify({ ok: true, contract: 'sync reconciliation ui' }, null, 2));
