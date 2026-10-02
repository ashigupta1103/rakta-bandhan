import assert from 'node:assert/strict';
import { test } from 'node:test';
import { supportContent, supportDeliveryMode } from '../support-content';

test('support delivery is off by default and never sends from the emulator', () => {
  assert.equal(supportDeliveryMode(false, false), 'disabled');
  assert.equal(supportDeliveryMode(false, true), 'disabled');
  assert.equal(supportDeliveryMode(true, true), 'local-only');
  assert.equal(supportDeliveryMode(true, false), 'send');
});
test('support emails preserve text and escape HTML', () => {
  const content = supportContent('Please use <script> & "quotes".');
  assert.match(content.html, /&lt;script&gt; &amp; &quot;quotes&quot;/);
  assert.match(content.text, /<script>/);
  assert.throws(() => supportContent(''));
  assert.throws(() => supportContent('a'.repeat(2001)));
});
