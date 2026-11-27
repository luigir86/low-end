// Sends the store listing in store/ (texts, phone screenshots, feature
// graphics, five languages) to Google Play through the Play Developer API,
// without publishing it. Run by .github/workflows/store-listing.yml.
//
//   node tool/play_listing.mjs validate   uploads into an edit, asks Play to
//                                         check it, then throws the edit away
//   node tool/play_listing.mjs draft      commits the edit with
//                                         changesNotSentForReview=true: the
//                                         changes wait in Play Console until
//                                         the owner presses "Send for review"
//   node tool/play_listing.mjs managed    commits it plainly: only when
//                                         Managed publishing is on, so the
//                                         changes wait for "Publish changes"
//
// The service account comes from PLAY_SERVICE_ACCOUNT_JSON and needs the
// "Manage store presence" permission. No packages: Node's own crypto and fetch.

import { createSign } from 'node:crypto';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const packageName = 'com.luigir86.low_end';
const locales = ['en-US', 'it-IT', 'es-ES', 'fr-FR', 'de-DE'];
const api = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}`;
const uploadApi = `https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/${packageName}`;

const mode = process.argv[2];
if (!['validate', 'draft', 'managed'].includes(mode)) {
  console.error('Usage: node tool/play_listing.mjs validate|draft|managed');
  process.exit(2);
}

function read(path) {
  return readFileSync(path, 'utf8').replace(/\r/g, '').trim();
}

// Texts first, all of them, so that nothing is sent when one is too long.
const limits = { title: 30, short_description: 80, full_description: 4000 };
const listings = {};
for (const locale of locales) {
  const dir = join('store', 'listing', locale);
  const texts = {};
  for (const [name, max] of Object.entries(limits)) {
    const text = read(join(dir, `${name}.txt`));
    const length = [...text].length;
    console.log(`${locale} ${name}: ${length} characters`);
    if (length === 0 || length > max) {
      throw new Error(`${dir}/${name}.txt: ${length} characters, Play allows 1 to ${max}`);
    }
    texts[name] = text;
  }
  listings[locale] = texts;
}

async function token() {
  const raw = process.env.PLAY_SERVICE_ACCOUNT_JSON;
  if (!raw) throw new Error('PLAY_SERVICE_ACCOUNT_JSON is missing (docs/play-release.md)');
  const account = JSON.parse(raw);
  const now = Math.floor(Date.now() / 1000);
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const unsigned = `${encode({ alg: 'RS256', typ: 'JWT' })}.${encode({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })}`;
  const signature = createSign('RSA-SHA256').update(unsigned).sign(account.private_key, 'base64url');
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${signature}`,
    }),
  });
  const body = await response.json();
  if (!response.ok) throw new Error(`Google sign-in refused: ${JSON.stringify(body)}`);
  return body.access_token;
}

const auth = `Bearer ${await token()}`;

async function call(method, url, { json, data, type } = {}) {
  const headers = { Authorization: auth };
  let body;
  if (json !== undefined) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(json);
  } else if (data !== undefined) {
    headers['Content-Type'] = type;
    body = data;
  }
  const response = await fetch(url, { method, headers, body });
  const text = await response.text();
  if (!response.ok) throw new Error(`${method} ${url.replace(api, '')}: ${response.status} ${text}`);
  return text ? JSON.parse(text) : {};
}

const edit = await call('POST', `${api}/edits`, { json: {} });
const editUrl = `${api}/edits/${edit.id}`;
console.log(`Edit ${edit.id} opened`);

let committed = false;
try {
  for (const locale of locales) {
    const texts = listings[locale];
    await call('PUT', `${editUrl}/listings/${locale}`, {
      json: {
        language: locale,
        title: texts.title,
        shortDescription: texts.short_description,
        fullDescription: texts.full_description,
      },
    });
    console.log(`${locale}: texts`);

    const images = [
      ['featureGraphic', [join('store', 'graphics', locale, 'feature-graphic-1024x500.png')]],
      [
        'phoneScreenshots',
        readdirSync(join('store', 'graphics', 'phone', locale))
          .filter((name) => name.endsWith('.png'))
          .sort()
          .map((name) => join('store', 'graphics', 'phone', locale, name)),
      ],
    ];
    for (const [type, files] of images) {
      if (files.length === 0 || !files.every(existsSync)) {
        throw new Error(`${locale} ${type}: missing files`);
      }
      await call('DELETE', `${editUrl}/listings/${locale}/${type}`);
      for (const file of files) {
        await call('POST', `${uploadApi}/edits/${edit.id}/listings/${locale}/${type}?uploadType=media`, {
          data: readFileSync(file),
          type: 'image/png',
        });
      }
      console.log(`${locale}: ${type} (${files.length})`);
    }
  }

  await call('POST', `${editUrl}:validate`);
  console.log('Play checked the edit: valid');

  if (mode === 'draft') {
    await call('POST', `${editUrl}:commit?changesNotSentForReview=true`);
    committed = true;
    console.log('Committed, NOT sent for review: Play Console > Publishing overview > Send for review');
  } else if (mode === 'managed') {
    await call('POST', `${editUrl}:commit`);
    committed = true;
    console.log('Committed: with Managed publishing on, it waits for "Publish changes"');
  }
} finally {
  if (!committed) {
    await call('DELETE', editUrl).catch((error) => console.error(error.message));
    console.log(`Edit ${edit.id} thrown away: nothing changed on Play`);
  }
}
