import { Suspense } from 'react';
import ContentTabBar from '@/components/admin/ContentTabBar';
import RangePicker from '@/components/admin/RangePicker';

// Lazy-import existing page content components
import AdminPlansPage from '../plans/page';
import AdminLibraryPage from '../library/page';
import AdminSeriesPage from '../series/page';
import AdminCategoriesPage from '../categories/page';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

interface ContentPageProps {
  searchParams: Promise<{ tab?: string; range?: string; [key: string]: string | undefined }>;
}

// ────────────────────────────────────────────────────────────────────────────
// Tabs
// ────────────────────────────────────────────────────────────────────────────

const CONTENT_TABS = [
  { id: 'plans', label: 'Plans' },
  { id: 'library', label: 'Library' },
  { id: 'series', label: 'Series' },
  { id: 'categories', label: 'Categories' },
];

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * Admin Content Page — server component
 *
 * Consolidated content management page with horizontal tab bar.
 * Four tabs: Plans, Library, Series, Categories.
 *
 * Each tab renders the content from the respective standalone page.
 * URL param ?tab= controls the active tab (deep-linkable).
 */
export default async function AdminContentPage({ searchParams }: ContentPageProps) {
  const params = await searchParams;
  const activeTab = params.tab ?? 'plans';

  return (
    <div>
      {/* Page header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
        <h1 className="text-2xl font-bold text-white">Content</h1>
        <Suspense fallback={null}>
          <RangePicker />
        </Suspense>
      </div>

      {/* Tab bar + content */}
      <ContentTabBar tabs={CONTENT_TABS} defaultTab={activeTab}>
        {(tab) => (
          <div className="mt-6">
            {tab === 'plans' && <AdminPlansPage searchParams={searchParams} />}
            {tab === 'library' && <AdminLibraryPage searchParams={searchParams} />}
            {tab === 'series' && <AdminSeriesPage />}
            {tab === 'categories' && <AdminCategoriesPage />}
          </div>
        )}
      </ContentTabBar>
    </div>
  );
}
