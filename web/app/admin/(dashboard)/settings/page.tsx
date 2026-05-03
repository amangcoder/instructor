import ContentTabBar from '@/components/admin/ContentTabBar';

// Import existing page content
import AppVersionPage from '../app-version/page';
import AdminsListPage from '../admins/page';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

interface SettingsPageProps {
  searchParams: Promise<{ tab?: string; search?: string; page?: string; pageSize?: string }>;
}

// ────────────────────────────────────────────────────────────────────────────
// Tabs
// ────────────────────────────────────────────────────────────────────────────

const SETTINGS_TABS = [
  { id: 'app-version', label: 'App Version' },
  { id: 'admins', label: 'Admins' },
];

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * Admin Settings Page — server component
 *
 * Consolidated settings page with horizontal tab bar.
 * Two tabs: App Version and Admins.
 *
 * URL param ?tab= controls the active tab (deep-linkable).
 */
export default async function AdminSettingsPage({ searchParams }: SettingsPageProps) {
  const params = await searchParams;
  const activeTab = params.tab ?? 'app-version';

  return (
    <div>
      {/* Page header */}
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">Settings</h1>
      </div>

      {/* Tab bar + content */}
      <ContentTabBar tabs={SETTINGS_TABS} defaultTab={activeTab}>
        {(tab) => (
          <div className="mt-6">
            {tab === 'app-version' && <AppVersionPage />}
            {tab === 'admins' && <AdminsListPage searchParams={searchParams} />}
          </div>
        )}
      </ContentTabBar>
    </div>
  );
}
