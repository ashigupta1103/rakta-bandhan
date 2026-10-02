import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from './firebase';

const edgeUrl = (import.meta.env.VITE_EDGE_URL ?? '').replace(/\/+$/, '');

async function media(method: 'GET' | 'DELETE', path: string): Promise<Response> {
  if (!edgeUrl) throw new Error('Set VITE_EDGE_URL to connect photo storage.');
  const token = await auth.currentUser?.getIdToken();
  if (!token) throw new Error('Sign in first.');
  const response = await fetch(`${edgeUrl}/media/${path}`, {
    method, headers: { Authorization: `Bearer ${token}` }, signal: AbortSignal.timeout(10000),
  });
  if (!response.ok && response.status !== 404) throw new Error('Could not access the photo. Try again.');
  return response;
}

export async function deleteMedia(path: string): Promise<void> {
  await media('DELETE', path);
}

export async function deleteIdProof(uid: string): Promise<void> {
  // No Worker configured: legacy Firestore proofs can still be removed.
  if (edgeUrl) await deleteMedia(`id_proofs/${encodeURIComponent(uid)}/proof.jpg`);
}

/** ID images need the admin's bearer token; never render a private Worker URL directly. */
export async function fetchIdProof(uid: string): Promise<string | null> {
  if (edgeUrl) {
    const response = await media('GET', `id_proofs/${encodeURIComponent(uid)}/proof.jpg`);
    if (response.status !== 404) {
      const blob = await response.blob();
      return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result as string);
        reader.onerror = () => reject(new Error('Could not read the ID photo.'));
        reader.readAsDataURL(blob);
      });
    }
  }
  const legacy = (await getDoc(doc(db, 'donors', uid, 'private', 'id_proof'))).data();
  if (typeof legacy?.base64 === 'string') return `data:${legacy.content_type ?? 'image/jpeg'};base64,${legacy.base64}`;
  const profile = (await getDoc(doc(db, 'donors', uid))).data();
  return typeof profile?.id_proof_base64 === 'string' ? `data:image/jpeg;base64,${profile.id_proof_base64}` : null;
}
