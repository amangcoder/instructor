import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import AppVersionForm from '../AppVersionForm';
import type { AppVersionConfigResponse } from '@/types/app-version';

const mockInitialConfig: AppVersionConfigResponse = {
  ios: { minVersion: '1.0.0', forceUpdateVersion: '1.1.0' },
  android: { minVersion: '1.0.0', forceUpdateVersion: '1.1.0' },
  enabled: true,
};

// Mock fetch globally
global.fetch = jest.fn();

describe('AppVersionForm', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    (global.fetch as jest.Mock).mockClear();
  });

  it('renders form with initial config values', () => {
    render(<AppVersionForm initialConfig={mockInitialConfig} />);

    // Both iOS and Android have the same minVersion ('1.0.0'), so use getAllByDisplayValue
    const minVersionInputs = screen.getAllByDisplayValue('1.0.0');
    const forceVersionInputs = screen.getAllByDisplayValue('1.1.0');

    expect(minVersionInputs.length).toBeGreaterThan(0);
    expect(forceVersionInputs.length).toBeGreaterThan(0);
  });

  it('renders iOS and Android sections', () => {
    render(<AppVersionForm initialConfig={mockInitialConfig} />);

    expect(screen.getByText('iOS Configuration')).toBeInTheDocument();
    expect(screen.getByText('Android Configuration')).toBeInTheDocument();
  });

  it('renders enabled toggle with initial value', () => {
    render(<AppVersionForm initialConfig={mockInitialConfig} />);

    const toggle = screen.getByRole('checkbox', {
      name: /Enable app version enforcement/i,
    }) as HTMLInputElement;

    expect(toggle.checked).toBe(true);
  });

  it('allows toggling enabled state', async () => {
    const user = userEvent.setup();
    render(<AppVersionForm initialConfig={mockInitialConfig} />);

    const toggle = screen.getByRole('checkbox', {
      name: /Enable app version enforcement/i,
    });

    await user.click(toggle);
    expect((toggle as HTMLInputElement).checked).toBe(false);

    await user.click(toggle);
    expect((toggle as HTMLInputElement).checked).toBe(true);
  });

  it('allows changing iOS minimum version', async () => {
    const user = userEvent.setup();
    render(<AppVersionForm initialConfig={mockInitialConfig} />);

    const iosMinInput = screen.getByLabelText('iOS minimum version');
    await user.clear(iosMinInput);
    await user.type(iosMinInput, '2.0.0');

    expect((iosMinInput as HTMLInputElement).value).toBe('2.0.0');
  });

  it('allows changing iOS force update version', async () => {
    const user = userEvent.setup();
    render(<AppVersionForm initialConfig={mockInitialConfig} />);

    const iosForceInput = screen.getByLabelText('iOS force update version');
    await user.clear(iosForceInput);
    await user.type(iosForceInput, '2.0.0');

    expect((iosForceInput as HTMLInputElement).value).toBe('2.0.0');
  });

  it('validates that force version must be >= min version for iOS', async () => {
    const user = userEvent.setup();
    render(<AppVersionForm initialConfig={mockInitialConfig} />);

    const iosMinInput = screen.getByLabelText('iOS minimum version');
    const iosForceInput = screen.getByLabelText('iOS force update version');
    const submitButton = screen.getByRole('button', { name: /Save Configuration/i });

    await user.clear(iosMinInput);
    await user.type(iosMinInput, '2.0.0');
    await user.clear(iosForceInput);
    await user.type(iosForceInput, '1.0.0');

    await user.click(submitButton);

    await waitFor(() => {
      expect(
        screen.getByText(/iOS: Force update version must be >= minimum version/),
      ).toBeInTheDocument();
    });
  });

  it('validates that force version must be >= min version for Android', async () => {
    const user = userEvent.setup();
    render(<AppVersionForm initialConfig={mockInitialConfig} />);

    const androidMinInput = screen.getByLabelText('Android minimum version');
    const androidForceInput = screen.getByLabelText('Android force update version');
    const submitButton = screen.getByRole('button', { name: /Save Configuration/i });

    await user.clear(androidMinInput);
    await user.type(androidMinInput, '2.0.0');
    await user.clear(androidForceInput);
    await user.type(androidForceInput, '1.5.0');

    await user.click(submitButton);

    await waitFor(() => {
      expect(
        screen.getByText(/Android: Force update version must be >= minimum version/),
      ).toBeInTheDocument();
    });
  });

  it('validates that min version is required', async () => {
    const user = userEvent.setup();
    render(<AppVersionForm initialConfig={mockInitialConfig} />);

    const iosMinInput = screen.getByLabelText('iOS minimum version');
    const submitButton = screen.getByRole('button', { name: /Save Configuration/i });

    await user.clear(iosMinInput);
    await user.click(submitButton);

    await waitFor(() => {
      expect(
        screen.getByText(/iOS: Minimum version is required/),
      ).toBeInTheDocument();
    });
  });

  it('validates that force version is required', async () => {
    const user = userEvent.setup();
    render(<AppVersionForm initialConfig={mockInitialConfig} />);

    const iosForceInput = screen.getByLabelText('iOS force update version');
    const submitButton = screen.getByRole('button', { name: /Save Configuration/i });

    await user.clear(iosForceInput);
    await user.click(submitButton);

    await waitFor(() => {
      expect(
        screen.getByText(/iOS: Force update version is required/),
      ).toBeInTheDocument();
    });
  });

  it('submits form successfully and shows success toast', async () => {
    const user = userEvent.setup();
    (global.fetch as jest.Mock).mockResolvedValue({
      ok: true,
      json: async () => mockInitialConfig,
    });

    render(<AppVersionForm initialConfig={mockInitialConfig} />);

    const submitButton = screen.getByRole('button', { name: /Save Configuration/i });
    await user.click(submitButton);

    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalledWith('/api/admin/app-version', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ios: mockInitialConfig.ios,
          android: mockInitialConfig.android,
          enabled: true,
        }),
      });
    });
  });

  it('displays error when API request fails', async () => {
    const user = userEvent.setup();
    (global.fetch as jest.Mock).mockResolvedValue({
      ok: false,
      json: async () => ({ message: 'Server validation failed' }),
    });

    render(<AppVersionForm initialConfig={mockInitialConfig} />);

    const submitButton = screen.getByRole('button', { name: /Save Configuration/i });
    await user.click(submitButton);

    await waitFor(() => {
      expect(
        screen.getByText(/Error saving configuration/),
      ).toBeInTheDocument();
      expect(screen.getByText('Server validation failed')).toBeInTheDocument();
    });
  });

  it('disables submit button while submitting', async () => {
    const user = userEvent.setup();
    (global.fetch as jest.Mock).mockImplementation(
      () =>
        new Promise(() => {
          // Never resolves to keep the loading state
        }),
    );

    render(<AppVersionForm initialConfig={mockInitialConfig} />);

    const submitButton = screen.getByRole('button', {
      name: /Save Configuration/i,
    }) as HTMLButtonElement;

    await user.click(submitButton);

    await waitFor(() => {
      expect(submitButton).toBeDisabled();
      expect(submitButton.textContent).toBe('Saving...');
    });
  });

  it('clears platform error when user modifies field', async () => {
    const user = userEvent.setup();
    render(<AppVersionForm initialConfig={mockInitialConfig} />);

    const iosMinInput = screen.getByLabelText('iOS minimum version');
    const iosForceInput = screen.getByLabelText('iOS force update version');
    const submitButton = screen.getByRole('button', { name: /Save Configuration/i });

    // Create validation error
    await user.clear(iosMinInput);
    await user.type(iosMinInput, '2.0.0');
    await user.clear(iosForceInput);
    await user.type(iosForceInput, '1.0.0');
    await user.click(submitButton);

    await waitFor(() => {
      expect(
        screen.getByText(/iOS: Force update version must be >= minimum version/),
      ).toBeInTheDocument();
    });

    // Modify field and error should clear
    await user.clear(iosForceInput);
    await user.type(iosForceInput, '2.5.0');

    expect(
      screen.queryByText(/iOS: Force update version must be >= minimum version/),
    ).not.toBeInTheDocument();
  });

  it('accepts equal version numbers (force = min)', async () => {
    const user = userEvent.setup();
    (global.fetch as jest.Mock).mockResolvedValue({
      ok: true,
      json: async () => mockInitialConfig,
    });

    render(<AppVersionForm initialConfig={mockInitialConfig} />);

    const iosMinInput = screen.getByLabelText('iOS minimum version');
    const iosForceInput = screen.getByLabelText('iOS force update version');
    const submitButton = screen.getByRole('button', { name: /Save Configuration/i });

    await user.clear(iosMinInput);
    await user.type(iosMinInput, '1.5.0');
    await user.clear(iosForceInput);
    await user.type(iosForceInput, '1.5.0');

    await user.click(submitButton);

    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalled();
    });

    expect(
      screen.queryByText(/Force update version must be >= minimum version/),
    ).not.toBeInTheDocument();
  });
});
