import { useCallback, useEffect, useRef, useState } from 'react';
import { getCountFromServer, getDocs, limit, onSnapshot, query, startAfter, type DocumentData, type Query, type QueryDocumentSnapshot } from 'firebase/firestore';

const PAGE = 50;

/** Live newest page plus explicit cursor reads. Live changes reset older pages. */
export function usePagedCollection<T>(base: Query<DocumentData>) {
  const [items, setItems] = useState<T[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [total, setTotal] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const cursor = useRef<QueryDocumentSnapshot<DocumentData> | undefined>(undefined);
  const generation = useRef(0);

  useEffect(() => {
    const invalidate = () => { generation.current++; };
    generation.current++;
    setItems([]); setLoading(true); setError(null); setTotal(null); setLoadingMore(false); setHasMore(false);
    cursor.current = undefined;
    const stop = onSnapshot(query(base, limit(PAGE)), (snapshot) => {
      const current = ++generation.current;
      setItems(snapshot.docs.map((d) => ({ ...d.data(), id: d.id } as T)));
      cursor.current = snapshot.docs[snapshot.docs.length - 1];
      setHasMore(snapshot.size === PAGE); setLoading(false); setLoadingMore(false);
      getCountFromServer(base).then((count) => { if (current === generation.current) setTotal(count.data().count); })
        .catch(() => { if (current === generation.current) setError('Could not load totals. Check your connection and indexes.'); });
    }, () => { setError('Could not load records. Check your access, connection and indexes.'); setLoading(false); });
    return () => { invalidate(); stop(); };
  }, [base]);

  const loadMore = useCallback(async () => {
    if (!cursor.current || !hasMore || loadingMore) return;
    const current = generation.current;
    setLoadingMore(true);
    try {
      const snapshot = await getDocs(query(base, startAfter(cursor.current), limit(PAGE)));
      if (current !== generation.current) return;
      setItems((previous) => {
        const next = new Map(previous.map((item) => [(item as { id: string }).id, item]));
        for (const d of snapshot.docs) next.set(d.id, { ...d.data(), id: d.id } as T);
        return [...next.values()];
      });
      cursor.current = snapshot.docs[snapshot.docs.length - 1];
      setHasMore(snapshot.size === PAGE);
    } catch { if (current === generation.current) setError('Could not load more records. Try again.'); }
    finally { if (current === generation.current) setLoadingMore(false); }
  }, [base, hasMore, loadingMore]);
  return { items, loading, loadingMore, hasMore, loadMore, total, error };
}
