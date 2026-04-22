import UsersListSection from '@/components/admin/UsersListSection';

interface PageProps {
  searchParams: Promise<{
    search?: string;
    page?: string;
    pageSize?: string;
  }>;
}

export default async function ConsumersListPage({ searchParams }: PageProps) {
  const params = await searchParams;
  return (
    <UsersListSection
      role="user"
      heading="Consumers"
      basePath="/admin/users-list"
      searchParams={params}
    />
  );
}
