import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import '@testing-library/jest-dom';

// ── Mocks ─────────────────────────────────────────────────────────────────────

const mockPush = jest.fn();

jest.mock('next/navigation', () => ({
  useRouter: () => ({ push: mockPush }),
}));

// Mock global fetch
const mockFetch = jest.fn();
global.fetch = mockFetch;

import AdminLoginPage from '../login/page';

// ── Helpers ───────────────────────────────────────────────────────────────────

function mockFetchSuccess(data: Record<string, unknown> = { success: true }) {
  mockFetch.mockResolvedValueOnce({
    ok: true,
    json: async () => data,
  });
}

function mockFetchError(
  status: number,
  data: Record<string, unknown> = { success: false, message: 'Auth failed.' },
) {
  mockFetch.mockResolvedValueOnce({
    ok: false,
    status,
    json: async () => data,
  });
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('AdminLoginPage', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  // ── Rendering ──────────────────────────────────────────────────────────

  it('renders the login heading', () => {
    render(<AdminLoginPage />);
    expect(
      screen.getByRole('heading', { name: 'Admin Login' }),
    ).toBeInTheDocument();
  });

  it('renders email step by default', () => {
    render(<AdminLoginPage />);
    expect(screen.getByLabelText('Email address')).toBeInTheDocument();
    expect(
      screen.getByRole('button', { name: 'Send OTP' }),
    ).toBeInTheDocument();
  });

  it('email input is required and has correct type', () => {
    render(<AdminLoginPage />);
    const emailInput = screen.getByLabelText('Email address');
    expect(emailInput).toHaveAttribute('type', 'email');
    expect(emailInput).toHaveAttribute('autocomplete', 'email');
  });

  // ── Step 1: Send OTP ──────────────────────────────────────────────────

  it('Send OTP button is disabled when email is empty', () => {
    render(<AdminLoginPage />);
    expect(screen.getByRole('button', { name: 'Send OTP' })).toBeDisabled();
  });

  it('calls POST /api/auth/session with login action on submit', async () => {
    const user = userEvent.setup();
    mockFetchSuccess();

    render(<AdminLoginPage />);

    await user.type(screen.getByLabelText('Email address'), 'admin@test.com');
    await user.click(screen.getByRole('button', { name: 'Send OTP' }));

    await waitFor(() => {
      expect(mockFetch).toHaveBeenCalledWith('/api/auth/session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'login', email: 'admin@test.com' }),
      });
    });
  });

  it('transitions to OTP step after successful login request', async () => {
    const user = userEvent.setup();
    mockFetchSuccess();

    render(<AdminLoginPage />);

    await user.type(screen.getByLabelText('Email address'), 'admin@test.com');
    await user.click(screen.getByRole('button', { name: 'Send OTP' }));

    await waitFor(() => {
      expect(screen.getByLabelText('Verification code')).toBeInTheDocument();
    });
    expect(screen.getByRole('button', { name: 'Verify' })).toBeInTheDocument();
  });

  it('shows error message when login request fails', async () => {
    const user = userEvent.setup();
    mockFetchError(400, { success: false, message: 'Auth failed.' });

    render(<AdminLoginPage />);

    await user.type(screen.getByLabelText('Email address'), 'bad@test.com');
    await user.click(screen.getByRole('button', { name: 'Send OTP' }));

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent('Auth failed.');
    });
  });

  // ── Step 2: Verify OTP ────────────────────────────────────────────────

  it('OTP input accepts only digits', async () => {
    const user = userEvent.setup();
    mockFetchSuccess();

    render(<AdminLoginPage />);

    // Get to OTP step
    await user.type(screen.getByLabelText('Email address'), 'admin@test.com');
    await user.click(screen.getByRole('button', { name: 'Send OTP' }));

    await waitFor(() => {
      expect(screen.getByLabelText('Verification code')).toBeInTheDocument();
    });

    const otpInput = screen.getByLabelText('Verification code');
    await user.type(otpInput, 'abc123def456');
    expect(otpInput).toHaveValue('123456');
  });

  it('Verify button is disabled when code is not 6 digits', async () => {
    const user = userEvent.setup();
    mockFetchSuccess();

    render(<AdminLoginPage />);

    await user.type(screen.getByLabelText('Email address'), 'admin@test.com');
    await user.click(screen.getByRole('button', { name: 'Send OTP' }));

    await waitFor(() => {
      expect(screen.getByLabelText('Verification code')).toBeInTheDocument();
    });

    expect(screen.getByRole('button', { name: 'Verify' })).toBeDisabled();

    await user.type(screen.getByLabelText('Verification code'), '12345');
    expect(screen.getByRole('button', { name: 'Verify' })).toBeDisabled();
  });

  it('calls POST /api/auth/session with verify action on OTP submit', async () => {
    const user = userEvent.setup();
    mockFetchSuccess(); // login
    mockFetchSuccess({ success: true, user: { role: 'admin' } }); // verify

    render(<AdminLoginPage />);

    await user.type(screen.getByLabelText('Email address'), 'admin@test.com');
    await user.click(screen.getByRole('button', { name: 'Send OTP' }));

    await waitFor(() => {
      expect(screen.getByLabelText('Verification code')).toBeInTheDocument();
    });

    await user.type(screen.getByLabelText('Verification code'), '654321');
    await user.click(screen.getByRole('button', { name: 'Verify' }));

    await waitFor(() => {
      expect(mockFetch).toHaveBeenLastCalledWith('/api/auth/session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'verify',
          email: 'admin@test.com',
          code: '654321',
        }),
      });
    });
  });

  it('redirects to /admin/overview on successful verification', async () => {
    const user = userEvent.setup();
    mockFetchSuccess(); // login
    mockFetchSuccess({ success: true, user: { role: 'admin' } }); // verify

    render(<AdminLoginPage />);

    await user.type(screen.getByLabelText('Email address'), 'admin@test.com');
    await user.click(screen.getByRole('button', { name: 'Send OTP' }));

    await waitFor(() => {
      expect(screen.getByLabelText('Verification code')).toBeInTheDocument();
    });

    await user.type(screen.getByLabelText('Verification code'), '654321');
    await user.click(screen.getByRole('button', { name: 'Verify' }));

    await waitFor(() => {
      expect(mockPush).toHaveBeenCalledWith('/admin/overview');
    });
  });

  it('shows error when verification fails', async () => {
    const user = userEvent.setup();
    mockFetchSuccess(); // login
    mockFetchError(401, {
      success: false,
      message: 'Authentication failed.',
    }); // verify

    render(<AdminLoginPage />);

    await user.type(screen.getByLabelText('Email address'), 'admin@test.com');
    await user.click(screen.getByRole('button', { name: 'Send OTP' }));

    await waitFor(() => {
      expect(screen.getByLabelText('Verification code')).toBeInTheDocument();
    });

    await user.type(screen.getByLabelText('Verification code'), '000000');
    await user.click(screen.getByRole('button', { name: 'Verify' }));

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent(
        'Authentication failed.',
      );
    });
  });

  // ── Back button ────────────────────────────────────────────────────────

  it('"Back to email" button returns to email step', async () => {
    const user = userEvent.setup();
    mockFetchSuccess();

    render(<AdminLoginPage />);

    await user.type(screen.getByLabelText('Email address'), 'admin@test.com');
    await user.click(screen.getByRole('button', { name: 'Send OTP' }));

    await waitFor(() => {
      expect(screen.getByLabelText('Verification code')).toBeInTheDocument();
    });

    await user.click(
      screen.getByRole('button', { name: /back to email/i }),
    );

    expect(screen.getByLabelText('Email address')).toBeInTheDocument();
  });

  // ── Network error ─────────────────────────────────────────────────────

  it('shows network error message on fetch failure', async () => {
    const user = userEvent.setup();
    mockFetch.mockRejectedValueOnce(new Error('Network error'));

    render(<AdminLoginPage />);

    await user.type(screen.getByLabelText('Email address'), 'admin@test.com');
    await user.click(screen.getByRole('button', { name: 'Send OTP' }));

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent(
        'Network error. Please try again.',
      );
    });
  });
});
