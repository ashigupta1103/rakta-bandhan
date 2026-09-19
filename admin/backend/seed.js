import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword } from 'firebase/auth';
import { getFirestore, collection, doc, setDoc } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyC-Maq9_JwK9gEaKAyC1-CDc995LlA2cPY",
  authDomain: "project-673480bf-b9b8-4e5b-8a1.firebaseapp.com",
  projectId: "project-673480bf-b9b8-4e5b-8a1",
  storageBucket: "project-673480bf-b9b8-4e5b-8a1.firebasestorage.app",
  messagingSenderId: "323116488555",
  appId: "1:323116488555:web:6d8f9b124a9b61e4b15e2e"
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

const bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
const names = ['Amit Sharma', 'Priya Singh', 'Rahul Verma', 'Sneha Patel', 'Vikram Malhotra', 'Neha Gupta', 'Rohan Desai', 'Kavita Iyer', 'Arjun Nair', 'Pooja Reddy'];
const cities = ['Mumbai', 'Delhi', 'Bangalore', 'Pune', 'Hyderabad'];

async function seed() {
  console.log("Logging in...");
  await signInWithEmailAndPassword(auth, 'admin@raktabandhan.com', '12345678');
  console.log("Logged in. Seeding data...");

  // 1. Seed Donors
  console.log("Seeding donors...");
  for (let i = 0; i < 10; i++) {
    const uid = `dummy_donor_${i}`;
    await setDoc(doc(db, 'donors', uid), {
      name: names[i],
      phone: `+91-98765${Math.floor(10000 + Math.random() * 90000)}`,
      blood_group: bloodGroups[Math.floor(Math.random() * bloodGroups.length)],
      geohash: 'te7uzj',
      lat: 19.0760 + (Math.random() * 0.1 - 0.05),
      lng: 72.8777 + (Math.random() * 0.1 - 0.05),
      is_available: Math.random() > 0.2,
      is_verified: Math.random() > 0.3,
      is_banned: false,
      created_at: new Date(Date.now() - Math.random() * 10000000000)
    });
  }

  // 2. Seed Hospitals
  console.log("Seeding hospitals...");
  const hospitalIds = [];
  for (let i = 1; i <= 3; i++) {
    const id = `hospital_${i}`;
    hospitalIds.push(id);
    await setDoc(doc(db, 'hospitals', id), {
      hospital_id: id,
      name: `City Care Hospital ${i}`,
      address: `${100 * i} Main Street`,
      city: cities[i],
      state: 'Maharashtra',
      contact_phone: '+91-800-555-010' + i,
      verified: true,
      created_by: 'admin_seed',
      created_at: new Date()
    });
  }

  // 3. Seed Requests
  console.log("Seeding requests...");
  const statuses = ['open', 'matched', 'fulfilled', 'expired', 'cancelled'];
  const urgencies = ['normal', 'urgent', 'critical'];
  for (let i = 0; i < 8; i++) {
    const reqId = `dummy_request_${i}`;
    await setDoc(doc(db, 'requests', reqId), {
      requester_uid: `requester_${i}`,
      hospital_id: hospitalIds[i % hospitalIds.length],
      blood_group: bloodGroups[Math.floor(Math.random() * bloodGroups.length)],
      units_needed: Math.floor(Math.random() * 3) + 1,
      urgency: urgencies[Math.floor(Math.random() * urgencies.length)],
      status: statuses[Math.floor(Math.random() * statuses.length)],
      created_at: new Date(Date.now() - Math.random() * 500000000),
      expires_at: new Date(Date.now() + 21600000)
    });
  }

  console.log("Data seeding complete!");
  process.exit(0);
}

seed().catch(console.error);
