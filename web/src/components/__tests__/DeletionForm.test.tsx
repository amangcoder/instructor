import React from 'react';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import '@testing-library/jest-dom';
import DeletionForm from '../DeletionForm';

// ────────────────────────────────────────────────────────────────────────────
// Global fetch mock
// ────────────────────────────────────────────────────────────────────────────

const mockFetch = jest.fn();
global.fetch = mockFetch;

// ────────────────────────────────────────────────────────────────────────────
// Timer setup for cooldown tests
// ────────────────────────────────────────────────────────────────────────────

beforeEach(() => {
  jest.useFakeTimers();
  mockFetch.mockReset();
});

afterEach(() => {
  jest.runOnlyPendingTimers();
  jest.useRealTimers();
});

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

const mockSuccessResponse = () => {
  mockFetch.mockResolvedValueOnce({
    ok: true,
    json: async () => ({ success: true, message: 'OK' }),
  });
};

const mockErrorResponse = (message = 'Server error') => {
  mockFetch.mockResolvedValueOnce({
    ok: false,
    json: async () => ({ message }),
  });
};

const mockNetworkError = () => {
  mockFetch.mockRejectedValueOnce(new Error('Network failure'));
};

// ────────────────────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────────────────────

describe('DeletionForm', () => {
  // ── Rendering ──────────────────────────────────────────────────────────────

  describe('Initial rendering', () => {
    it('renders the email input field', () => {
      render(<DeletionForm />);
      expect(screen.getByLabelText(/email address/i)).toBeInTheDocument();
    });

    it('renders two scope radio options', () => {
      render(<DeletionForm />);
      expect(screen.getByRole('radio', { name: /full account deletion/i })).toBeInTheDocument();
      expect(screen.getByRole('radio', { name: /selective data deletion/i })).toBeInTheDocument();
    });

    it('renders the optional reason textarea', () => {
      render(<DeletionForm />);
      expect(screen.getByLabelText(/reason/i)).toBeInTheDocument();
    });

    it('renders the submit button', () => {
      render(<DeletionForm />);
      expect(
        screen.getByRole('button', { name: /submit deletion request/i }),
      ).toBeInTheDocument();
    });

    it('does not show selective checkboxes by default', () => {
      render(<DeletionForm />);
      expect(screen.queryByText(/plans/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/tts cache/i)).not.toBeInTheDocument();
    });
  });

  // ── Email validation ───────────────────────────────────────────────────────

  describe('Email validation', () => {
    it('shows error message for invalid email on blur', async () => {
      render(<DeletionForm />);
      const emailInput = screen.getByLabelText(/email address/i);

      await userEvent.type(emailInput, 'invalid-email');
      fireEvent.blur(emailInput);

      expect(
        await screen.findByText('Please enter a valid email address'),
      ).toBeInTheDocument();
    });

    it('shows error for email with no domain', async () => {
      render(<DeletionForm />);
      const emailInput = screen.getByLabelText(/email address/i);

      await userEvent.type(emailInput, 'user@');
      fireEvent.blur(emailInput);

      expect(
        await screen.findByText('Please enter a valid email address'),
      ).toBeInTheDocument();
    });

    it('clears error message when valid email is entered', async () => {
      render(<DeletionForm />);
      const emailInput = screen.getByLabelText(/email address/i);

      await userEvent.type(emailInput, 'bad');
      fireEvent.blur(emailInput);
      expect(
        await screen.findByText('Please enter a valid email address'),
      ).toBeInTheDocument();

      await userEvent.clear(emailInput);
      await userEvent.type(emailInput, 'valid@example.com');
      expect(
        screen.queryByText('Please enter a valid email address'),
      ).not.toBeInTheDocument();
    });

    it('marks email input as aria-invalid when email error exists', async () => {
      render(<DeletionForm />);
      const emailInput = screen.getByLabelText(/email address/i);

      await userEvent.type(emailInput, 'notvalid');
      fireEvent.blur(emailInput);

      await waitFor(() =>
        expect(emailInput).toHaveAttribute('aria-invalid', 'true'),
      );
    });
  });

  // ── Form submission prevention ─────────────────────────────────────────────

  describe('Form submission prevention', () => {
    it('prevents submission when email is invalid', async () => {
      render(<DeletionForm />);

      await userEvent.type(screen.getByLabelText(/email address/i), 'bad-email');
      fireEvent.click(screen.getByRole('radio', { name: /full account deletion/i }));
      fireEvent.click(screen.getByRole('button', { name: /submit/i }));

      expect(mockFetch).not.toHaveBeenCalled();
      expect(
        screen.getByText('Please enter a valid email address'),
      ).toBeInTheDocument();
    });

    it('prevents submission when no scope is selected', async () => {
      render(<DeletionForm />);

      await userEvent.type(
        screen.getByLabelText(/email address/i),
        'user@example.com',
      );
      fireEvent.click(screen.getByRole('button', { name: /submit/i }));

      expect(mockFetch).not.toHaveBeenCalled();
    });

    it('prevents submission when selective scope is chosen but no items selected', async () => {
      render(<DeletionForm />);

      await userEvent.type(
        screen.getByLabelText(/email address/i),
        'user@example.com',
      );
      fireEvent.click(screen.getByRole('radio', { name: /selective data deletion/i }));
      fireEvent.click(screen.getByRole('button', { name: /submit/i }));

      expect(mockFetch).not.toHaveBeenCalled();
    });
  });

  // ── Selective scope checkboxes ─────────────────────────────────────────────

  describe('Selective scope', () => {
    it('shows selective checkboxes when selective radio is selected', () => {
      render(<DeletionForm />);
      fireEvent.click(screen.getByRole('radio', { name: /selective data deletion/i }));

      expect(screen.getByText(/plans/i)).toBeInTheDocument();
      expect(screen.getByText(/tts cache/i)).toBeInTheDocument();
      expect(screen.getByText(/profile data/i)).toBeInTheDocument();
    });

    it('hides selective checkboxes when full-account radio is re-selected', () => {
      render(<DeletionForm />);
      fireEvent.click(screen.getByRole('radio', { name: /selective data deletion/i }));
      expect(screen.getByText(/tts cache/i)).toBeInTheDocument();

      fireEvent.click(screen.getByRole('radio', { name: /full account deletion/i }));
      expect(screen.queryByText(/tts cache/i)).not.toBeInTheDocument();
    });

    it('allows toggling selective checkboxes', () => {
      render(<DeletionForm />);
      fireEvent.click(screen.getByRole('radio', { name: /selective data deletion/i }));

      const checkboxes = screen.getAllByRole('checkbox');
      expect(checkboxes[0]).not.toBeChecked();
      fireEvent.click(checkboxes[0]);
      expect(checkboxes[0]).toBeChecked();
      fireEvent.click(checkboxes[0]);
      expect(checkboxes[0]).not.toBeChecked();
    });
  });

  // ── Successful submission ──────────────────────────────────────────────────

  describe('Successful submission', () => {
    it('shows success message after successful form submission', async () => {
      mockSuccessResponse();
      render(<DeletionForm />);

      await userEvent.type(
        screen.getByLabelText(/email address/i),
        'user@example.com',
      );
      fireEvent.click(screen.getByRole('radio', { name: /full account deletion/i }));

      await act(async () => {
        fireEvent.click(screen.getByRole('button', { name: /submit/i }));
      });

      await waitFor(() =>
        expect(
          screen.getByText(/request submitted successfully/i),
        ).toBeInTheDocument(),
      );
    });

    it('clears form fields after successful submission', async () => {
      mockSuccessResponse();
      render(<DeletionForm />);

      const emailInput = screen.getByLabelText(/email address/i);
      await userEvent.type(emailInput, 'user@example.com');
      fireEvent.click(screen.getByRole('radio', { name: /full account deletion/i }));

      await act(async () => {
        fireEvent.click(screen.getByRole('button', { name: /submit/i }));
      });

      await waitFor(() => {
        expect(emailInput).toHaveValue('');
      });

      // Scope radio is reset — full account radio should be unchecked
      expect(
        screen.getByRole('radio', { name: /full account deletion/i }),
      ).not.toBeChecked();
    });

    it('disables submit button during 60-second cooldown', async () => {
      mockSuccessResponse();
      render(<DeletionForm />);

      await userEvent.type(
        screen.getByLabelText(/email address/i),
        'user@example.com',
      );
      fireEvent.click(screen.getByRole('radio', { name: /full account deletion/i }));

      await act(async () => {
        fireEvent.click(screen.getByRole('button', { name: /submit/i }));
      });

      await waitFor(() =>
        expect(
          screen.getByText(/retry in \d+s/i),
        ).toBeInTheDocument(),
      );

      const button = screen.getByRole('button', { name: /retry in/i });
      expect(button).toBeDisabled();
    });

    it('re-enables submit button after 60-second cooldown expires', async () => {
      mockSuccessResponse();
      render(<DeletionForm />);

      await userEvent.type(
        screen.getByLabelText(/email address/i),
        'user@example.com',
      );
      fireEvent.click(screen.getByRole('radio', { name: /full account deletion/i }));

      await act(async () => {
        fireEvent.click(screen.getByRole('button', { name: /submit/i }));
      });

      // Fast-forward 60 seconds
      await act(async () => {
        jest.advanceTimersByTime(60_000);
      });

      await waitFor(() =>
        expect(
          screen.getByRole('button', { name: /submit deletion request/i }),
        ).not.toBeDisabled(),
      );
    });

    it('sends correct payload to /api/deletion-request', async () => {
      mockSuccessResponse();
      render(<DeletionForm />);

      await userEvent.type(
        screen.getByLabelText(/email address/i),
        'test@example.com',
      );
      fireEvent.click(screen.getByRole('radio', { name: /full account deletion/i }));
      await userEvent.type(screen.getByLabelText(/reason/i), 'Leaving the app');

      await act(async () => {
        fireEvent.click(screen.getByRole('button', { name: /submit/i }));
      });

      await waitFor(() => expect(mockFetch).toHaveBeenCalledTimes(1));

      const [url, options] = mockFetch.mock.calls[0] as [string, RequestInit];
      expect(url).toBe('/api/deletion-request');
      expect(options.method).toBe('POST');

      const body = JSON.parse(options.body as string) as {
        email: string;
        scope: string;
        reason: string;
      };
      expect(body.email).toBe('test@example.com');
      expect(body.scope).toBe('full');
      expect(body.reason).toBe('Leaving the app');
    });
  });

  // ── Error handling ─────────────────────────────────────────────────────────

  describe('Error handling', () => {
    it('shows error message on server error response', async () => {
      mockErrorResponse('Service temporarily unavailable');
      render(<DeletionForm />);

      await userEvent.type(
        screen.getByLabelText(/email address/i),
        'user@example.com',
      );
      fireEvent.click(screen.getByRole('radio', { name: /full account deletion/i }));

      await act(async () => {
        fireEvent.click(screen.getByRole('button', { name: /submit/i }));
      });

      await waitFor(() =>
        expect(screen.getByText(/service temporarily unavailable/i)).toBeInTheDocument(),
      );
    });

    it('shows error message on network failure', async () => {
      mockNetworkError();
      render(<DeletionForm />);

      await userEvent.type(
        screen.getByLabelText(/email address/i),
        'user@example.com',
      );
      fireEvent.click(screen.getByRole('radio', { name: /full account deletion/i }));

      await act(async () => {
        fireEvent.click(screen.getByRole('button', { name: /submit/i }));
      });

      await waitFor(() =>
        expect(screen.getByText(/network failure/i)).toBeInTheDocument(),
      );
    });

    it('shows "Try again" button after error', async () => {
      mockErrorResponse();
      render(<DeletionForm />);

      await userEvent.type(
        screen.getByLabelText(/email address/i),
        'user@example.com',
      );
      fireEvent.click(screen.getByRole('radio', { name: /full account deletion/i }));

      await act(async () => {
        fireEvent.click(screen.getByRole('button', { name: /submit/i }));
      });

      await waitFor(() =>
        expect(screen.getByRole('button', { name: /try again/i })).toBeInTheDocument(),
      );
    });

    it('restores the form (without clearing data) when "Try again" is clicked', async () => {
      mockErrorResponse();
      render(<DeletionForm />);

      const emailInput = screen.getByLabelText(/email address/i);
      await userEvent.type(emailInput, 'user@example.com');
      fireEvent.click(screen.getByRole('radio', { name: /full account deletion/i }));

      await act(async () => {
        fireEvent.click(screen.getByRole('button', { name: /submit/i }));
      });

      await waitFor(() =>
        expect(screen.getByRole('button', { name: /try again/i })).toBeInTheDocument(),
      );

      // Click "Try again"
      fireEvent.click(screen.getByRole('button', { name: /try again/i }));

      // Form should be back with same email
      await waitFor(() =>
        expect(screen.getByLabelText(/email address/i)).toHaveValue('user@example.com'),
      );

      expect(
        screen.getByRole('button', { name: /submit deletion request/i }),
      ).toBeInTheDocument();
    });
  });

  // ── Accessibility ──────────────────────────────────────────────────────────

  describe('Accessibility', () => {
    it('uses a <form> with aria-label', () => {
      const { container } = render(<DeletionForm />);
      const form = container.querySelector('form');
      expect(form).toHaveAttribute('aria-label', 'Data deletion request form');
    });

    it('uses a <fieldset> for scope selection', () => {
      const { container } = render(<DeletionForm />);
      expect(container.querySelector('fieldset')).toBeInTheDocument();
    });

    it('announces success message via role="alert"', async () => {
      mockSuccessResponse();
      render(<DeletionForm />);

      await userEvent.type(
        screen.getByLabelText(/email address/i),
        'user@example.com',
      );
      fireEvent.click(screen.getByRole('radio', { name: /full account deletion/i }));

      await act(async () => {
        fireEvent.click(screen.getByRole('button', { name: /submit/i }));
      });

      await waitFor(() => {
        const alerts = screen.getAllByRole('alert');
        const successAlert = alerts.find((el) =>
          el.textContent?.includes('Request submitted successfully'),
        );
        expect(successAlert).toBeInTheDocument();
      });
    });

    it('announces error message via role="alert"', async () => {
      mockErrorResponse('Failed');
      render(<DeletionForm />);

      await userEvent.type(
        screen.getByLabelText(/email address/i),
        'user@example.com',
      );
      fireEvent.click(screen.getByRole('radio', { name: /full account deletion/i }));

      await act(async () => {
        fireEvent.click(screen.getByRole('button', { name: /submit/i }));
      });

      await waitFor(() => {
        const alerts = screen.getAllByRole('alert');
        const errorAlert = alerts.find((el) =>
          el.textContent?.includes('Something went wrong'),
        );
        expect(errorAlert).toBeInTheDocument();
      });
    });

    it('submit button has aria-busy="true" while submitting', async () => {
      // Create a pending promise to simulate slow request
      let resolve: (value: unknown) => void;
      const pendingPromise = new Promise((res) => {
        resolve = res;
      });
      mockFetch.mockReturnValueOnce(pendingPromise);

      render(<DeletionForm />);

      await userEvent.type(
        screen.getByLabelText(/email address/i),
        'user@example.com',
      );
      fireEvent.click(screen.getByRole('radio', { name: /full account deletion/i }));

      act(() => {
        fireEvent.click(screen.getByRole('button', { name: /submit/i }));
      });

      await waitFor(() =>
        expect(
          screen.getByRole('button', { name: /submitting/i }),
        ).toHaveAttribute('aria-busy', 'true'),
      );

      // Cleanup — resolve the pending promise
      await act(async () => {
        resolve!({ ok: true, json: async () => ({}) });
      });
    });
  });
});
