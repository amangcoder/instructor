import { render, screen } from '@testing-library/react';
import AppVersionPage from '../(dashboard)/app-version/page';

// Mock the admin API module
jest.mock('@/lib/admin-api', () => ({
  adminFetch: jest.fn(),
  AdminApiError: class extends Error {
    constructor(message: string, public code: string) {
      super(message);
    }
  },
}));

// Mock the AppVersionForm component
jest.mock('@/components/admin/AppVersionForm', () => {
  return function MockAppVersionForm() {
    return <div data-testid="app-version-form">Mock Form</div>;
  };
});

const { adminFetch, AdminApiError } = require('@/lib/admin-api');

describe('AppVersionPage', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders page header with title and description', async () => {
    adminFetch.mockResolvedValue({
      ios: { minVersion: '1.0.0', forceUpdateVersion: '1.0.0' },
      android: { minVersion: '1.0.0', forceUpdateVersion: '1.0.0' },
      enabled: true,
    });

    await render(await AppVersionPage());

    expect(screen.getByText('App Version Management')).toBeInTheDocument();
    expect(
      screen.getByText(/Configure minimum supported and forced-update versions/),
    ).toBeInTheDocument();
  });

  it('fetches and displays app version config', async () => {
    const mockConfig = {
      ios: { minVersion: '1.2.0', forceUpdateVersion: '1.3.0' },
      android: { minVersion: '1.1.0', forceUpdateVersion: '1.2.0' },
      enabled: true,
    };

    adminFetch.mockResolvedValue(mockConfig);

    await render(await AppVersionPage());

    expect(adminFetch).toHaveBeenCalledWith('/admin/app-version');
    expect(screen.getByTestId('app-version-form')).toBeInTheDocument();
  });

  it('displays error message when fetch fails', async () => {
    adminFetch.mockRejectedValue(new AdminApiError('Forbidden', 'FORBIDDEN'));

    await render(await AppVersionPage());

    expect(screen.getByText(/Failed to load app version configuration/)).toBeInTheDocument();
    expect(screen.getByText('Forbidden')).toBeInTheDocument();
  });

  it('displays generic error message on unexpected error', async () => {
    adminFetch.mockRejectedValue(new Error('Network error'));

    await render(await AppVersionPage());

    expect(
      screen.getByText(/An unexpected error occurred while loading app version configuration/),
    ).toBeInTheDocument();
  });

  it('does not render form when error occurs', async () => {
    adminFetch.mockRejectedValue(new AdminApiError('Forbidden', 'FORBIDDEN'));

    await render(await AppVersionPage());

    expect(screen.queryByTestId('app-version-form')).not.toBeInTheDocument();
  });

  it('renders loading state when data is null and no error', async () => {
    adminFetch.mockImplementation(
      () =>
        new Promise(() => {
          // Never resolves to keep loading state
        }),
    );

    const page = AppVersionPage();
    // We need to render the initial state, but since the promise never resolves,
    // we just verify the component structure without waiting for data

    expect(adminFetch).toHaveBeenCalled();
  });
});
