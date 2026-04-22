import { redirect } from 'next/navigation';

/**
 * /admin → redirects to /admin/overview
 *
 * This page exists solely to redirect users who navigate to /admin
 * to the overview dashboard. The (dashboard) route group ensures
 * they are authenticated before reaching this redirect.
 */
export default function AdminIndexPage() {
  redirect('/admin/overview');
}
