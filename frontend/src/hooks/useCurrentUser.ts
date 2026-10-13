import { useEffect, useState } from 'react';

import { HttpUtil } from '@/utils';

export interface CurrentUser {
  id: number;
  username: string;
  role: string;
  isAdmin: boolean;
}

let cached: CurrentUser | null = null;
let inflight: Promise<CurrentUser | null> | null = null;

async function fetchCurrentUser(): Promise<CurrentUser | null> {
  try {
    const msg = await HttpUtil.get<CurrentUser>('/me', undefined, { silent: true });
    const data = msg?.obj;
    if (data && typeof data.isAdmin === 'boolean') {
      cached = {
        id: data.id,
        username: data.username,
        role: data.role,
        isAdmin: data.isAdmin,
      };
      return cached;
    }
  } catch {
    // Not logged in (401) — a null user means the login redirect handles it.
  }
  return null;
}

// Loads the logged-in account once and shares the result app-wide. The sidebar
// and route guards use it to hide what a limited admin may not reach.
export function useCurrentUser(): CurrentUser | null {
  const [user, setUser] = useState<CurrentUser | null>(cached);

  useEffect(() => {
    if (cached) return;
    if (!inflight)
      inflight = fetchCurrentUser().finally(() => {
        inflight = null;
      });
    inflight.then(setUser);
  }, []);

  return user;
}

export function getCurrentUser(): CurrentUser | null {
  return cached;
}

export function clearCurrentUser(): void {
  cached = null;
  inflight = null;
}
