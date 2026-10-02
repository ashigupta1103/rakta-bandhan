import { collection, orderBy, query, where, type QueryConstraint } from 'firebase/firestore';
import { db } from './firebase';

export function donorSearch(input: string) {
  const value = input.trim().toLowerCase();
  if (value.startsWith('@')) return { field: 'username', value: value.slice(1), prefix: true };
  if (value.includes('@')) return { field: 'email', value, prefix: false };
  const digits = value.replace(/[\s+()-]/g, '');
  if (/^(91)?[6-9]\d{9}$/.test(digits)) return { field: 'phone', value: digits.length === 12 ? digits.slice(2) : digits, prefix: false };
  return { field: 'name_lower', value, prefix: true };
}

export function donorsQuery(bloodGroup?: string, verifiedOnly?: boolean, search = '', pending = false) {
  const constraints: QueryConstraint[] = [];
  if (bloodGroup) constraints.push(where('blood_group', '==', bloodGroup));
  if (verifiedOnly || pending) constraints.push(where('is_verified', '==', !pending), where('is_banned', '==', false));
  if (search.trim()) {
    const part = donorSearch(search);
    if (part.prefix) constraints.push(where(part.field, '>=', part.value), where(part.field, '<=', `${part.value}\uf8ff`), orderBy(part.field));
    else constraints.push(where(part.field, '==', part.value), orderBy('created_at', 'desc'));
  } else constraints.push(orderBy('created_at', 'desc'));
  return query(collection(db, 'donors'), ...constraints);
}
