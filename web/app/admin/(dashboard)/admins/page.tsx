import UsersListSection from '@/components/admin/UsersListSection';

interface PageProps {
  searchParams: Promise<{
    search?: string;
    page?: string;
    pageSize?: string;
  }>;
}

export default async function AdminsListPage({ searchParams }: PageProps) {
  const params = await searchParams;
  return (
    <UsersListSection
      role="admin"
      heading="Admins"
      basePath="/admin/admins"
      searchParams={params}
    />
  );
}
