// Security-rules tests. Run from this folder:
//   npm install
//   npm test          (starts the Firestore + Storage emulators, runs, stops)
//
// Each test signs in as a specific kind of user (verified / unverified /
// admin / stranger) and checks the rules allow exactly what the app needs.

import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  addDoc,
  collection,
  writeBatch,
} from 'firebase/firestore';
import { ref, uploadBytes } from 'firebase/storage';

let env;

const verified = (uid) => env.authenticatedContext(uid, { email: `${uid}@example.com`, email_verified: true }).firestore();
const codeLogin = (uid) => env.authenticatedContext(uid, { login: 'email_otp' }).firestore();
const unverified = (uid) => env.authenticatedContext(uid, { email: `${uid}@example.com`, email_verified: false }).firestore();
const storageAs = (uid, verifiedEmail = true) =>
  env.authenticatedContext(uid, { email: `${uid}@example.com`, email_verified: verifiedEmail }).storage();

const future = (days) => Timestamp.fromMillis(Date.now() + days * 86400000);
const past = (days) => Timestamp.fromMillis(Date.now() - days * 86400000);

function donorDoc(extra = {}) {
  return {
    name: 'Test Donor',
    phone: '9876543210',
    email: 'donor@example.com',
    blood_group: 'O+',
    lat: 13.08,
    lng: 80.27,
    geohash: 'tf2ez',
    is_available: true,
    is_verified: false,
    is_banned: false,
    active_request_id: null,
    created_at: serverTimestamp(),
    ...extra,
  };
}

function openRequest(extra = {}) {
  return {
    requester_uid: 'requester',
    requester_name: 'Req',
    blood_group: 'O+',
    units_needed: 1,
    urgency: 'urgent',
    location_label: 'Apollo Hospital, Greams Road',
    geohash: 'tf2ezabcd',
    lat: 13.06,
    lng: 80.25,
    status: 'open',
    created_at: Timestamp.fromMillis(Date.now() - 60000),
    expires_at: future(0.25),
    ...extra,
  };
}

/** Seeds documents with rules disabled. */
async function seed(fn) {
  await env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

function register(db, uid, name = 'donor_one', extra = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, `usernames/${name}`), { uid, created_at: serverTimestamp() });
  batch.set(doc(db, `donors/${uid}`), donorDoc({ username: name, username_changed_at: serverTimestamp(), ...extra }));
  batch.set(doc(db, `donors_public/${uid}`), { name: 'Test Donor', username: name, is_verified: false, is_available: true });
  return batch.commit();
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-rakta-bandhan',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
    storage: { rules: readFileSync('../storage.rules', 'utf8') },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

describe('sign-up and verified accounts', () => {
  test('an unverified account cannot create a donor profile', async () => {
    await assertFails(setDoc(doc(unverified('u1'), 'donors/u1'), donorDoc()));
  });

  test('a verified account can create its own donor profile', async () => {
    await assertSucceeds(register(verified('u1'), 'u1'));
  });

  test('an account signed in with an emailed code counts as verified', async () => {
    await assertSucceeds(register(codeLogin('u2'), 'u2'));
    await assertSucceeds(addDoc(collection(codeLogin('u2'), 'requests'), openRequest({ requester_uid: 'u2' })));
  });

  test('login codes are never readable or writable from the app', async () => {
    await assertFails(getDoc(doc(verified('u1'), 'login_codes/anything')));
    await assertFails(setDoc(doc(verified('u1'), 'login_codes/anything'), { code_hash: 'x' }));
  });

  test('nobody can create a profile that is already verified', async () => {
    await assertFails(setDoc(doc(verified('u1'), 'donors/u1'), donorDoc({ is_verified: true })));
  });

  test('an unverified account cannot raise a request', async () => {
    await assertFails(addDoc(collection(unverified('requester'), 'requests'), openRequest()));
  });

  test('a verified account can raise a request', async () => {
    await assertSucceeds(addDoc(collection(verified('requester'), 'requests'), openRequest()));
  });

  test('the public listing never carries a phone number', async () => {
    await assertFails(
      setDoc(doc(verified('u1'), 'donors_public/u1'), { name: 'A', blood_group: 'O+', is_available: true, is_verified: false, phone: '9' }),
    );
    await assertSucceeds(
      setDoc(doc(verified('u1'), 'donors_public/u1'), { name: 'A', blood_group: 'O+', is_available: true, is_verified: false, area: 'Adyar, Chennai' }),
    );
  });
});

describe('private data', () => {
  test('a donor profile is readable by its owner only', async () => {
    await seed((db) => setDoc(doc(db, 'donors/u1'), donorDoc()));
    await assertSucceeds(getDoc(doc(verified('u1'), 'donors/u1')));
    await assertFails(getDoc(doc(verified('stranger'), 'donors/u1')));
  });

  test('an open request is public; a matched one is not', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'requests/open1'), openRequest());
      await setDoc(doc(db, 'requests/matched1'), openRequest({ status: 'matched', matched_donor_id: 'donor' }));
    });
    await assertSucceeds(getDoc(doc(verified('stranger'), 'requests/open1')));
    await assertFails(getDoc(doc(verified('stranger'), 'requests/matched1')));
    await assertSucceeds(getDoc(doc(verified('donor'), 'requests/matched1')));
  });
});

describe('username claims', () => {
  const change = (db, uid, name, old, release = true) => {
    const batch = writeBatch(db);
    batch.set(doc(db, `usernames/${name}`), { uid, created_at: serverTimestamp() });
    batch.update(doc(db, `donors/${uid}`), { username: name, username_changed_at: serverTimestamp() });
    batch.update(doc(db, `donors_public/${uid}`), { username: name });
    if (old && release) batch.delete(doc(db, `usernames/${old}`));
    return batch.commit();
  };
  async function existing(changedAt = past(31)) {
    await seed(async (db) => {
      await setDoc(doc(db, 'donors/u1'), donorDoc({ username: 'donor_old', username_changed_at: changedAt }));
      await setDoc(doc(db, 'donors_public/u1'), { username: 'donor_old', is_verified: false });
      await setDoc(doc(db, 'usernames/donor_old'), { uid: 'u1', created_at: past(40) });
    });
  }
  test('registration requires a claim and matching public mirror', async () => {
    await assertFails(setDoc(doc(verified('u1'), 'donors/u1'), donorDoc({ username: 'donor_one', username_changed_at: serverTimestamp() })));
    await assertSucceeds(register(verified('u1'), 'u1'));
    await assertSucceeds(getDoc(doc(verified('u2'), 'usernames/donor_one')));
    await assertFails(register(verified('u2'), 'u2'));
  });
  test('uppercase, invalid formats and reserved names are rejected', async () => {
    for (const name of ['ABC', 'ab', '1abc', '_abc', 'bad-name', 'a'.repeat(21), 'admin', 'support', 'raktabandhan']) {
      await assertFails(register(verified('u1'), 'u1', name));
    }
  });
  test('a claim cannot be created for someone else or without the profile write', async () => {
    await assertFails(setDoc(doc(verified('u1'), 'usernames/donor_one'), { uid: 'u2', created_at: serverTimestamp() }));
    await assertFails(setDoc(doc(verified('u1'), 'usernames/donor_one'), { uid: 'u1', created_at: serverTimestamp() }));
  });
  test('claims cannot be listed, overwritten or deleted while still in use', async () => {
    await existing();
    const db = verified('u1');
    await assertFails(getDocs(collection(db, 'usernames')));
    await assertFails(updateDoc(doc(db, 'usernames/donor_old'), { created_at: serverTimestamp() }));
    await assertFails(deleteDoc(doc(db, 'usernames/donor_old')));
  });
  test('a change releases the old name and stamps a new cooldown', async () => {
    await existing();
    await assertSucceeds(change(verified('u1'), 'u1', 'donor_new', 'donor_old'));
    const old = await getDoc(doc(verified('u1'), 'usernames/donor_old'));
    if (old.exists()) throw new Error('old claim was not released');
    await assertFails(change(verified('u1'), 'u1', 'donor_next', 'donor_new'));
  });
  test('the cooldown and old-claim release cannot be bypassed', async () => {
    await existing(past(1));
    await assertFails(change(verified('u1'), 'u1', 'donor_new', 'donor_old'));
    await existing();
    await assertFails(change(verified('u1'), 'u1', 'donor_new', 'donor_old', false));
    await assertFails(updateDoc(doc(verified('u1'), 'donors/u1'), { username_changed_at: past(90) }));
    await assertFails(updateDoc(doc(verified('u1'), 'donors/u1'), { username: 'donor_new' }));
    await assertFails(updateDoc(doc(verified('u1'), 'donors_public/u1'), { username: 'donor_new' }));
  });
  test('legacy members can choose once and banned members cannot claim', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'donors/u1'), donorDoc());
      await setDoc(doc(db, 'donors_public/u1'), { is_verified: false });
    });
    await assertSucceeds(change(verified('u1'), 'u1', 'donor_first'));
    await seed((db) => updateDoc(doc(db, 'donors/u1'), { is_banned: true, username_changed_at: past(31) }));
    await assertFails(change(verified('u1'), 'u1', 'donor_second', 'donor_first'));
  });
  test('account deletion releases its claim atomically; admin can remove claims', async () => {
    await existing();
    const db = verified('u1');
    const batch = writeBatch(db);
    batch.delete(doc(db, 'usernames/donor_old'));
    batch.delete(doc(db, 'donors/u1'));
    batch.delete(doc(db, 'donors_public/u1'));
    await assertSucceeds(batch.commit());
    await existing();
    await seed((db) => setDoc(doc(db, 'admins/admin1'), {}));
    await assertSucceeds(deleteDoc(doc(verified('admin1'), 'usernames/donor_old')));
  });
});

describe('community story editing', () => {
  test('authors edit only content and their own photo; moderation and attribution stay protected', async () => {
    await seed((db) => setDoc(doc(db, 'community_stories/story1'), { author_uid: 'u1', author_name: 'Donor', body: 'Original', topic: 'Other', created_at: past(1) }));
    const ref = doc(verified('u1'), 'community_stories/story1');
    await assertSucceeds(updateDoc(ref, { body: 'Edited', topic: 'Other', edited_at: serverTimestamp() }));
    await assertFails(updateDoc(ref, { body: 'x', author_uid: 'u2', edited_at: serverTimestamp() }));
    await assertFails(updateDoc(ref, { is_hidden: false, edited_at: serverTimestamp() }));
    await assertFails(updateDoc(ref, { image_path: 'community/u2/photo.jpg', edited_at: serverTimestamp() }));
    await assertFails(updateDoc(doc(verified('u2'), 'community_stories/story1'), { body: 'x', edited_at: serverTimestamp() }));
  });
});

describe('90-day cooldown', () => {
  test('a resting donor cannot switch themselves back to available', async () => {
    await seed((db) => setDoc(doc(db, 'donors/u1'), donorDoc({ is_available: false, reactivation_scheduled_at: future(60) })));
    await assertFails(updateDoc(doc(verified('u1'), 'donors/u1'), { is_available: true }));
  });

  test('a resting donor cannot shorten or remove the rest period', async () => {
    await seed((db) => setDoc(doc(db, 'donors/u1'), donorDoc({ is_available: false, reactivation_scheduled_at: future(60) })));
    await assertFails(updateDoc(doc(verified('u1'), 'donors/u1'), { reactivation_scheduled_at: future(1) }));
  });

  test('after the rest period the donor can switch back on', async () => {
    await seed((db) => setDoc(doc(db, 'donors/u1'), donorDoc({ is_available: false, reactivation_scheduled_at: past(1) })));
    await assertSucceeds(updateDoc(doc(verified('u1'), 'donors/u1'), { is_available: true }));
  });

  test('a donor can still edit their name while resting', async () => {
    await seed((db) => setDoc(doc(db, 'donors/u1'), donorDoc({ is_available: false, reactivation_scheduled_at: future(60) })));
    await assertSucceeds(updateDoc(doc(verified('u1'), 'donors/u1'), { name: 'New Name' }));
  });
});

describe('two-sided donation completion', () => {
  const matched = (extra = {}) => openRequest({ status: 'matched', matched_donor_id: 'donor', matched_donor_name: 'D', ...extra });

  test('the donor confirms first — the request stays matched', async () => {
    await seed((db) => setDoc(doc(db, 'requests/r1'), matched()));
    await assertSucceeds(updateDoc(doc(verified('donor'), 'requests/r1'), { donor_confirmed_at: serverTimestamp() }));
  });

  test('the donor cannot close the request alone', async () => {
    await seed((db) => setDoc(doc(db, 'requests/r1'), matched()));
    await assertFails(
      updateDoc(doc(verified('donor'), 'requests/r1'), { donor_confirmed_at: serverTimestamp(), status: 'fulfilled', fulfilled_at: serverTimestamp() }),
    );
  });

  test('the requester confirming second closes it', async () => {
    await seed((db) => setDoc(doc(db, 'requests/r1'), matched({ donor_confirmed_at: past(0.01) })));
    await assertSucceeds(
      updateDoc(doc(verified('requester'), 'requests/r1'), { requester_confirmed_at: serverTimestamp(), status: 'fulfilled', fulfilled_at: serverTimestamp() }),
    );
  });

  test('the requester confirming first leaves it matched; the donor then closes it', async () => {
    await seed((db) => setDoc(doc(db, 'requests/r1'), matched()));
    await assertFails(
      updateDoc(doc(verified('requester'), 'requests/r1'), { requester_confirmed_at: serverTimestamp(), status: 'fulfilled', fulfilled_at: serverTimestamp() }),
    );
    await assertSucceeds(updateDoc(doc(verified('requester'), 'requests/r1'), { requester_confirmed_at: serverTimestamp() }));
    await assertSucceeds(
      updateDoc(doc(verified('donor'), 'requests/r1'), { donor_confirmed_at: serverTimestamp(), status: 'fulfilled', fulfilled_at: serverTimestamp() }),
    );
  });

  test('a stranger cannot confirm anything', async () => {
    await seed((db) => setDoc(doc(db, 'requests/r1'), matched()));
    await assertFails(updateDoc(doc(verified('stranger'), 'requests/r1'), { donor_confirmed_at: serverTimestamp() }));
  });

  test('a confirmation cannot be back-dated', async () => {
    await seed((db) => setDoc(doc(db, 'requests/r1'), matched()));
    await assertFails(updateDoc(doc(verified('donor'), 'requests/r1'), { donor_confirmed_at: past(5) }));
  });
});

describe('accepting requests', () => {
  test('request documents refuse newly copied phone numbers', async () => {
    await assertSucceeds(setDoc(doc(verified('requester'), 'requests/clean'), openRequest()));
    await assertFails(setDoc(doc(verified('requester'), 'requests/leak'), openRequest({ requester_phone: '9000000000' })));
    await assertFails(updateDoc(doc(verified('requester'), 'requests/clean'), {
      requester_phone: '9000000000', requester_deleted: true,
    }));
  });

  test('legacy phone numbers can be removed while deleting an account', async () => {
    await seed((db) => setDoc(doc(db, 'requests/legacy'), openRequest({ requester_phone: '9000000000' })));
    await assertSucceeds(updateDoc(doc(verified('requester'), 'requests/legacy'), {
      requester_phone: deleteField(), requester_name: 'Deleted user', requester_deleted: true,
    }));
    const data = (await getDoc(doc(verified('requester'), 'requests/legacy'))).data();
    if (data.requester_phone !== undefined) throw new Error('legacy phone survived deletion');
  });
  /** The write Backend.acceptRequest makes: the request goes to matched and the donor's own lock moves, in one batch. */
  async function accept(uid, requestId) {
    const db = verified(uid);
    const batch = writeBatch(db);
    batch.update(doc(db, `requests/${requestId}`), {
      status: 'matched',
      matched_donor_id: uid,
      matched_donor_name: 'D',
      requester_phone: deleteField(),
      matched_donor_phone: deleteField(),
      matched_at: serverTimestamp(),
    });
    batch.update(doc(db, `donors/${uid}`), { active_request_id: requestId });
    return batch.commit();
  }

  const seedDonor = (extra = {}) => seed((db) => setDoc(doc(db, 'donors/donor'), donorDoc(extra)));

  test('a verified donor can accept an open request', async () => {
    await seedDonor();
    await seed((db) => setDoc(doc(db, 'requests/r1'), openRequest()));
    await assertSucceeds(accept('donor', 'r1'));
  });

  test('an unverified account cannot accept', async () => {
    await seed((db) => setDoc(doc(db, 'requests/r1'), openRequest()));
    await assertFails(updateDoc(doc(unverified('donor'), 'requests/r1'), { status: 'matched', matched_donor_id: 'donor' }));
  });

  test('a donor cannot accept on someone else\'s behalf', async () => {
    await seedDonor();
    await seed((db) => setDoc(doc(db, 'requests/r1'), openRequest()));
    await assertFails(updateDoc(doc(verified('donor'), 'requests/r1'), { status: 'matched', matched_donor_id: 'someone-else' }));
  });

  describe('one active match per donor', () => {
    const matchedTo = (uid, extra = {}) => openRequest({ status: 'matched', matched_donor_id: uid, ...extra });

    test('accepting without taking the donor\'s own lock is refused', async () => {
      await seedDonor();
      await seed((db) => setDoc(doc(db, 'requests/r1'), openRequest()));
      await assertFails(
        updateDoc(doc(verified('donor'), 'requests/r1'), { status: 'matched', matched_donor_id: 'donor', matched_donor_name: 'D', matched_at: serverTimestamp() }),
      );
    });

    test('a donor on a live match cannot take a second request', async () => {
      await seedDonor({ active_request_id: 'r0' });
      await seed(async (db) => {
        await setDoc(doc(db, 'requests/r0'), matchedTo('donor'));
        await setDoc(doc(db, 'requests/r1'), openRequest());
      });
      await assertFails(accept('donor', 'r1'));
    });

    test('a lock pointing at a cancelled request is replaced', async () => {
      await seedDonor({ active_request_id: 'r0' });
      await seed(async (db) => {
        await setDoc(doc(db, 'requests/r0'), matchedTo('donor', { status: 'cancelled' }));
        await setDoc(doc(db, 'requests/r1'), openRequest());
      });
      await assertSucceeds(accept('donor', 'r1'));
    });

    test('a lock pointing at a request that no longer exists is replaced', async () => {
      await seedDonor({ active_request_id: 'ghost' });
      await seed((db) => setDoc(doc(db, 'requests/r1'), openRequest()));
      await assertSucceeds(accept('donor', 'r1'));
    });

    test('a lock pointing at someone else\'s match is replaced', async () => {
      await seedDonor({ active_request_id: 'r0' });
      await seed(async (db) => {
        await setDoc(doc(db, 'requests/r0'), matchedTo('another-donor'));
        await setDoc(doc(db, 'requests/r1'), openRequest());
      });
      await assertSucceeds(accept('donor', 'r1'));
    });

    test('a completed donation still owed its cooldown blocks a new match', async () => {
      await seedDonor({ active_request_id: 'r0' });
      await seed(async (db) => {
        await setDoc(doc(db, 'requests/r0'), matchedTo('donor', { status: 'fulfilled' }));
        await setDoc(doc(db, 'requests/r1'), openRequest());
      });
      await assertFails(accept('donor', 'r1'));
    });

    test('a resting donor cannot accept, and can once the rest is over', async () => {
      await seedDonor({ reactivation_scheduled_at: future(30) });
      await seed((db) => setDoc(doc(db, 'requests/r1'), openRequest()));
      await assertFails(accept('donor', 'r1'));
      await seedDonor({ reactivation_scheduled_at: past(1) });
      await assertSucceeds(accept('donor', 'r1'));
    });
  });
});

describe('donation records', () => {
  const fulfilled = (extra = {}) =>
    openRequest({
      status: 'fulfilled',
      matched_donor_id: 'donor',
      donor_confirmed_at: past(0.02),
      requester_confirmed_at: past(0.01),
      fulfilled_at: past(0.01),
      ...extra,
    });
  const record = (extra = {}) => ({
    donor_id: 'donor',
    request_id: 'r1',
    donation_date: serverTimestamp(),
    confirmed_by: 'self',
    hospital: 'Apollo Hospital, Greams Road',
    blood_group: 'O+',
    ...extra,
  });

  test('the donor who completes the request writes their record in the same transaction', async () => {
    await seed((db) =>
      setDoc(doc(db, 'requests/r1'), openRequest({ status: 'matched', matched_donor_id: 'donor', requester_confirmed_at: past(0.01) })),
    );
    const db = verified('donor');
    const batch = writeBatch(db);
    batch.update(doc(db, 'requests/r1'), { donor_confirmed_at: serverTimestamp(), status: 'fulfilled', fulfilled_at: serverTimestamp() });
    batch.set(doc(db, 'donation_history/r1'), record());
    await assertSucceeds(batch.commit());
  });

  test('the donor\'s app can write the record after the requester completed the request', async () => {
    await seed((db) => setDoc(doc(db, 'requests/r1'), fulfilled()));
    await assertSucceeds(setDoc(doc(verified('donor'), 'donation_history/r1'), record()));
  });

  test('a record for an unfinished request is refused', async () => {
    await seed((db) => setDoc(doc(db, 'requests/r1'), openRequest({ status: 'matched', matched_donor_id: 'donor' })));
    await assertFails(setDoc(doc(verified('donor'), 'donation_history/r1'), record()));
  });

  test('a record for a request that does not exist is refused', async () => {
    await assertFails(setDoc(doc(verified('donor'), 'donation_history/r1'), record()));
  });

  test('a record for someone else\'s donation is refused', async () => {
    await seed((db) => setDoc(doc(db, 'requests/r1'), fulfilled({ matched_donor_id: 'another-donor' })));
    await assertFails(setDoc(doc(verified('donor'), 'donation_history/r1'), record()));
  });

  test('the record must be keyed by the request id', async () => {
    await seed((db) => setDoc(doc(db, 'requests/r1'), fulfilled()));
    await assertFails(addDoc(collection(verified('donor'), 'donation_history'), record()));
    await assertFails(setDoc(doc(verified('donor'), 'donation_history/other'), record()));
  });

  test('a second record for the same request is refused', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'requests/r1'), fulfilled());
      await setDoc(doc(db, 'donation_history/r1'), { ...record(), donation_date: past(1) });
    });
    await assertFails(setDoc(doc(verified('donor'), 'donation_history/r1'), record()));
  });

  test('extra fields, an admin stamp, a back-dated time or the wrong details are refused', async () => {
    await seed((db) => setDoc(doc(db, 'requests/r1'), fulfilled()));
    const d = verified('donor');
    await assertFails(setDoc(doc(d, 'donation_history/r1'), record({ verified_by: 'donor' })));
    await assertFails(setDoc(doc(d, 'donation_history/r1'), record({ confirmed_by: 'admin' })));
    await assertFails(setDoc(doc(d, 'donation_history/r1'), record({ donation_date: past(30) })));
    await assertFails(setDoc(doc(d, 'donation_history/r1'), record({ hospital: 'Somewhere else' })));
    await assertFails(setDoc(doc(d, 'donation_history/r1'), record({ blood_group: 'AB-' })));
    await assertFails(setDoc(doc(d, 'donation_history/r1'), record({ donor_id: 'someone-else' })));
  });

  test('an admin can still write any record', async () => {
    await seed((db) => setDoc(doc(db, 'admins/boss'), { role: 'admin' }));
    await assertSucceeds(
      setDoc(doc(verified('boss'), 'donation_history/anything'), { ...record({ request_id: 'whatever' }), confirmed_by: 'admin', verified_by: 'boss' }),
    );
  });
});

describe('chat', () => {
  test('only the two matched people can message, while matched', async () => {
    await seed((db) => setDoc(doc(db, 'requests/r1'), openRequest({ status: 'matched', matched_donor_id: 'donor' })));
    const msg = (uid) => ({ sender_uid: uid, kind: 'text', text: 'On my way', sent_at: serverTimestamp() });
    await assertSucceeds(addDoc(collection(verified('donor'), 'requests/r1/messages'), msg('donor')));
    await assertFails(addDoc(collection(verified('stranger'), 'requests/r1/messages'), msg('stranger')));
  });

  test('messages over 1000 characters are refused', async () => {
    await seed((db) => setDoc(doc(db, 'requests/r1'), openRequest({ status: 'matched', matched_donor_id: 'donor' })));
    await assertFails(
      addDoc(collection(verified('donor'), 'requests/r1/messages'), { sender_uid: 'donor', kind: 'text', text: 'x'.repeat(1001) }),
    );
  });
});

describe('community posts', () => {
  const post = (uid, extra = {}) => ({
    author_uid: uid,
    author_name: 'A',
    topic: 'Gratitude',
    body: 'Thank you to everyone who came.',
    created_at: serverTimestamp(),
    ...extra,
  });

  test('a verified member can post, with a photo in their own folder', async () => {
    await assertSucceeds(addDoc(collection(verified('u1'), 'community_stories'), post('u1', { image_path: 'community/u1/p1.jpg', image_url: 'https://x' })));
  });

  test('a post cannot point at someone else\'s photo', async () => {
    await assertFails(addDoc(collection(verified('u1'), 'community_stories'), post('u1', { image_path: 'community/u2/p1.jpg' })));
  });

  test('only the author (or an admin) can delete a post', async () => {
    await seed((db) => setDoc(doc(db, 'community_stories/s1'), post('u1')));
    await assertFails(deleteDoc(doc(verified('u2'), 'community_stories/s1')));
    await assertSucceeds(deleteDoc(doc(verified('u1'), 'community_stories/s1')));
  });
});

describe('impact counter', () => {
  const impact = (n, month = '2026-10') => ({ month_key: month, donations_this_month: n, updated_at: serverTimestamp() });
  const serverJobsOn = () => seed((db) => setDoc(doc(db, 'config/features'), { server_jobs: true }));

  test('before functions are deployed, the app bumps it by exactly one', async () => {
    await assertSucceeds(setDoc(doc(verified('u1'), 'public_stats/impact'), impact(1)));
    await assertSucceeds(updateDoc(doc(verified('u2'), 'public_stats/impact'), impact(2)));
    await assertFails(updateDoc(doc(verified('u2'), 'public_stats/impact'), impact(9)), 'jumping by more than one');
    await assertSucceeds(updateDoc(doc(verified('u2'), 'public_stats/impact'), impact(1, '2026-11')), 'a new month starts again at 1');
  });

  test('once server jobs are on, only an admin can change it', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'public_stats/impact'), impact(5));
      await setDoc(doc(db, 'admins/boss'), { role: 'admin' });
    });
    await assertSucceeds(updateDoc(doc(verified('u1'), 'public_stats/impact'), impact(6)));
    await serverJobsOn();
    await assertFails(updateDoc(doc(verified('u1'), 'public_stats/impact'), impact(7)));
    await assertFails(setDoc(doc(verified('u1'), 'public_stats/other'), impact(1)));
    await assertSucceeds(updateDoc(doc(verified('boss'), 'public_stats/impact'), impact(40)));
  });

  test('config switches can be read by anyone signed in and written only by an admin', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'config/features'), { server_jobs: false });
      await setDoc(doc(db, 'admins/boss'), { role: 'admin' });
    });
    await assertSucceeds(getDoc(doc(verified('u1'), 'config/features')));
    await assertFails(updateDoc(doc(verified('u1'), 'config/features'), { server_jobs: true }));
    await assertSucceeds(updateDoc(doc(verified('boss'), 'config/features'), { server_jobs: true }));
  });
});

describe('admin-only areas', () => {
  test('only an admin can queue a broadcast', async () => {
    await seed((db) => setDoc(doc(db, 'admins/boss'), { role: 'admin' }));
    const b = { title: 'Blood camp Sunday', body: 'Adyar, 9am', blood_group: null, created_at: serverTimestamp() };
    await assertFails(addDoc(collection(verified('u1'), 'broadcasts'), b));
    await assertSucceeds(addDoc(collection(verified('boss'), 'broadcasts'), b));
  });

  test('a testimonial needs the member\'s consent and goes to the private queue', async () => {
    const t = { author_uid: 'u1', name: 'A', quote: 'Found a donor in twenty minutes.', role: 'Patient’s son', created_at: serverTimestamp() };
    await assertFails(addDoc(collection(verified('u1'), 'testimonial_submissions'), t));
    await assertSucceeds(addDoc(collection(verified('u1'), 'testimonial_submissions'), { ...t, consent_to_publish: true }));
    await assertFails(addDoc(collection(verified('u1'), 'testimonials'), t));
  });

  test('members cannot read the testimonial queue', async () => {
    await seed((db) => setDoc(doc(db, 'testimonial_submissions/t1'), { author_uid: 'u1', quote: 'x'.repeat(20), consent_to_publish: true }));
    await assertFails(getDoc(doc(verified('u2'), 'testimonial_submissions/t1')));
  });
});

describe('storage: community photos', () => {
  const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0]);

  test('a verified member can upload an image to their own folder', async () => {
    await assertSucceeds(uploadBytes(ref(storageAs('u1'), 'community/u1/p1.jpg'), jpeg, { contentType: 'image/jpeg' }));
  });

  test('uploading into someone else\'s folder is refused', async () => {
    await assertFails(uploadBytes(ref(storageAs('u1'), 'community/u2/p1.jpg'), jpeg, { contentType: 'image/jpeg' }));
  });

  test('non-images are refused', async () => {
    await assertFails(uploadBytes(ref(storageAs('u1'), 'community/u1/x.pdf'), jpeg, { contentType: 'application/pdf' }));
  });

  test('files over 2 MB are refused', async () => {
    await assertFails(uploadBytes(ref(storageAs('u1'), 'community/u1/big.jpg'), new Uint8Array(2 * 1024 * 1024 + 1), { contentType: 'image/jpeg' }));
  });

  test('unverified accounts cannot upload', async () => {
    await assertFails(uploadBytes(ref(storageAs('u1', false), 'community/u1/p1.jpg'), jpeg, { contentType: 'image/jpeg' }));
  });
});
