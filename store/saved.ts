import { useState, useCallback } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

const STORAGE_KEY = '@wirecutter/saved_products';

export function useSavedProducts() {
  const [savedIds, setSavedIds] = useState<Set<string>>(new Set());
  const [loaded, setLoaded] = useState(false);

  const load = useCallback(async () => {
    try {
      const raw = await AsyncStorage.getItem(STORAGE_KEY);
      if (raw) {
        setSavedIds(new Set(JSON.parse(raw)));
      }
    } finally {
      setLoaded(true);
    }
  }, []);

  const toggle = useCallback(
    async (productId: string) => {
      setSavedIds((prev) => {
        const next = new Set(prev);
        if (next.has(productId)) {
          next.delete(productId);
        } else {
          next.add(productId);
        }
        AsyncStorage.setItem(STORAGE_KEY, JSON.stringify([...next]));
        return next;
      });
    },
    []
  );

  const isSaved = useCallback(
    (productId: string) => savedIds.has(productId),
    [savedIds]
  );

  return { savedIds, loaded, load, toggle, isSaved };
}
