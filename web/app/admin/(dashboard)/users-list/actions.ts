'use server';

import { revalidatePath } from 'next/cache';
import { adminFetch, AdminApiError } from '@/lib/admin-api';

export type UpdateRoleResult =
  | { ok: true; role: 'user' | 'admin' }
  | { ok: false; error: string };

// Only 'user' is accepted — promotion to admin must be granted via DB directly.
export async function updateUserRoleAction(
  userId: string,
  role: 'user',
): Promise<UpdateRoleResult> {
  try {
    const result = await adminFetch<{ id: string; role: 'user' | 'admin' }>(
      `/admin/users/${userId}/role`,
      { method: 'PATCH', body: { role } },
    );
    revalidatePath('/admin/users-list');
    return { ok: true, role: result.role };
  } catch (err) {
    const message =
      err instanceof AdminApiError
        ? err.message
        : err instanceof Error
          ? err.message
          : 'Failed to update role';
    return { ok: false, error: message };
  }
}
