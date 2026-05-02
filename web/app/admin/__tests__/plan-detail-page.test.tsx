/**
 * Tests for the admin Plan Detail page.
 *
 * Since this is a React Server Component, we test by calling the page
 * function directly and inspecting the returned element tree.
 *
 * AC-010: Admin manages hierarchy without DB access
 * AC-011: 4th-level depth attempts show 422 error as toast
 * REQ-016: SubPlanTree displays recursive hierarchy; VoiceGrid displays status pills
 */
import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';

// ── Mocks ──────────────────────────────────────────────────────────────────

const mockAdminFetch = jest.fn();

jest.mock('@/lib/admin-api', () => ({
  adminFetch: (...args: unknown[]) => mockAdminFetch(...args),
  AdminApiError: class AdminApiError extends Error {
    code: string;
    constructor(message: string, code: string) {
      super(message);
      this.name = 'AdminApiError';
      this.code = code;
    }
  },
}));

// Mock client components — they require browser APIs (drag events, useState)
jest.mock('@/components/admin/SubPlanTree', () => ({
  __esModule: true,
  default: ({ planId, tree }: { planId: string; tree: { id: string; name: string; children: unknown[] } }) => (
    <div data-testid="sub-plan-tree" data-plan-id={planId}>
      SubPlanTree({tree.name}, children={tree.children.length})
    </div>
  ),
}));

jest.mock('@/components/admin/VoiceGrid', () => ({
  __esModule: true,
  default: ({ planId, voices }: { planId: string; voices: unknown[] }) => (
    <div data-testid="voice-grid" data-plan-id={planId}>
      VoiceGrid(count={voices.length})
    </div>
  ),
}));

jest.mock('@/components/admin/PublishToggle', () => ({
  __esModule: true,
  default: ({ planId, initialValue }: { planId: string; initialValue: boolean }) => (
    <div data-testid="publish-toggle" data-plan-id={planId}>
      PublishToggle({initialValue ? 'published' : 'draft'})
    </div>
  ),
}));

jest.mock('@/components/admin/VisibilitySelector', () => ({
  __esModule: true,
  default: ({ planId, initialValue }: { planId: string; initialValue: string }) => (
    <div data-testid="visibility-selector" data-plan-id={planId}>
      VisibilitySelector({initialValue})
    </div>
  ),
}));

jest.mock('@/components/admin/PlanStepList', () => ({
  __esModule: true,
  default: ({ planId, steps }: { planId: string; steps: unknown[] }) => (
    <div data-testid="plan-step-list" data-plan-id={planId}>
      PlanStepList(count={steps.length})
    </div>
  ),
}));

jest.mock('@/components/admin/PlanDetailsEditor', () => ({
  __esModule: true,
  default: ({ planId }: { planId: string }) => (
    <div data-testid="plan-details-editor" data-plan-id={planId}>
      PlanDetailsEditor
    </div>
  ),
}));

// ── Import after mocks ─────────────────────────────────────────────────────

import AdminPlanDetailPage from '../(dashboard)/plans/[id]/page';

// ── Test data ───────────────────────────────────────────────────────────────

const MOCK_PLAN = {
  id: 'plan-001',
  name: 'Morning Mindfulness',
  description: 'A guided meditation plan',
  parentPlanId: null,
  position: 0,
  visibility: 'public' as const,
  isPublished: true,
  ownerUserId: null,
  ttsStatus: 'ready',
  createdAt: '2025-01-01T00:00:00Z',
  updatedAt: '2025-04-01T00:00:00Z',
};

const MOCK_TREE = {
  id: 'plan-001',
  name: 'Morning Mindfulness',
  parentPlanId: null,
  position: 0,
  visibility: 'public',
  isPublished: true,
  depth: 0,
  children: [
    {
      id: 'sub-001',
      name: 'Breathing Exercise',
      parentPlanId: 'plan-001',
      position: 0,
      visibility: 'public',
      isPublished: true,
      depth: 1,
      children: [],
    },
    {
      id: 'sub-002',
      name: 'Body Scan',
      parentPlanId: 'plan-001',
      position: 1,
      visibility: 'public',
      isPublished: false,
      depth: 1,
      children: [],
    },
  ],
};

const MOCK_VOICES = [
  {
    id: 'pv-001',
    planId: 'plan-001',
    voiceId: 'voice-001',
    locale: 'en-US',
    status: 'ready' as const,
    audioUrl: 'https://example.com/audio.mp3',
    durationMs: 45000,
    errorMsg: null,
    generatedAt: '2025-03-01T00:00:00Z',
    voice: { displayName: 'Neural Voice A', slug: 'neural-a' },
  },
  {
    id: 'pv-002',
    planId: 'plan-001',
    voiceId: 'voice-002',
    locale: 'en-US',
    status: 'failed' as const,
    audioUrl: null,
    durationMs: null,
    errorMsg: 'TTS provider timeout',
    generatedAt: null,
    voice: { displayName: 'Neural Voice B', slug: 'neural-b' },
  },
];

// ── Tests ───────────────────────────────────────────────────────────────────

describe('AdminPlanDetailPage', () => {
  beforeEach(() => {
    mockAdminFetch.mockReset();
  });

  it('renders all sections when all fetches succeed', async () => {
    mockAdminFetch.mockImplementation((path: string) => {
      if (path.includes('/admin/plans/plan-001') && !path.includes('tree') && !path.includes('voices')) {
        return Promise.resolve(MOCK_PLAN);
      }
      if (path.includes('/tree')) {
        return Promise.resolve(MOCK_TREE);
      }
      if (path.includes('/voices')) {
        return Promise.resolve(MOCK_VOICES);
      }
      return Promise.reject(new Error('Unknown path'));
    });

    const page = await AdminPlanDetailPage({
      params: Promise.resolve({ id: 'plan-001' }),
    });
    render(page);

    // Page header
    expect(screen.getByText('Morning Mindfulness')).toBeInTheDocument();
    expect(screen.getByText(/plan-001/)).toBeInTheDocument();

    // All four components rendered
    expect(screen.getByTestId('sub-plan-tree')).toBeInTheDocument();
    expect(screen.getByTestId('voice-grid')).toBeInTheDocument();
    expect(screen.getByTestId('publish-toggle')).toBeInTheDocument();
    expect(screen.getByTestId('visibility-selector')).toBeInTheDocument();

    // SubPlanTree shows correct children count
    expect(screen.getByTestId('sub-plan-tree')).toHaveTextContent('children=2');

    // VoiceGrid shows correct voice count
    expect(screen.getByTestId('voice-grid')).toHaveTextContent('count=2');

    // PublishToggle shows correct state
    expect(screen.getByTestId('publish-toggle')).toHaveTextContent('published');

    // VisibilitySelector shows correct value
    expect(screen.getByTestId('visibility-selector')).toHaveTextContent('public');
  });

  it('shows error when plan fetch fails', async () => {
    mockAdminFetch.mockRejectedValue(new Error('Unauthorized'));

    const page = await AdminPlanDetailPage({
      params: Promise.resolve({ id: 'plan-001' }),
    });
    render(page);

    expect(screen.getByRole('alert')).toHaveTextContent('Unauthorized');
    expect(screen.getByText(/Back to Plans/)).toBeInTheDocument();
  });

  it('renders plan with tree error isolated (REQ-019 pattern)', async () => {
    mockAdminFetch.mockImplementation((path: string) => {
      if (path.includes('/admin/plans/plan-001') && !path.includes('tree') && !path.includes('voices')) {
        return Promise.resolve(MOCK_PLAN);
      }
      if (path.includes('/tree')) {
        return Promise.reject(new Error('Tree fetch failed'));
      }
      if (path.includes('/voices')) {
        return Promise.resolve(MOCK_VOICES);
      }
      return Promise.reject(new Error('Unknown path'));
    });

    const page = await AdminPlanDetailPage({
      params: Promise.resolve({ id: 'plan-001' }),
    });
    render(page);

    // Plan still renders
    expect(screen.getByText('Morning Mindfulness')).toBeInTheDocument();

    // Tree error shown but voice grid still works
    expect(screen.getByText('Tree fetch failed')).toBeInTheDocument();
    expect(screen.getByTestId('voice-grid')).toBeInTheDocument();
    expect(screen.getByTestId('publish-toggle')).toBeInTheDocument();
  });

  it('renders plan with voices error isolated', async () => {
    mockAdminFetch.mockImplementation((path: string) => {
      if (path.includes('/admin/plans/plan-001') && !path.includes('tree') && !path.includes('voices')) {
        return Promise.resolve(MOCK_PLAN);
      }
      if (path.includes('/tree')) {
        return Promise.resolve(MOCK_TREE);
      }
      if (path.includes('/voices')) {
        return Promise.reject(new Error('Voice fetch failed'));
      }
      return Promise.reject(new Error('Unknown path'));
    });

    const page = await AdminPlanDetailPage({
      params: Promise.resolve({ id: 'plan-001' }),
    });
    render(page);

    // Plan still renders
    expect(screen.getByText('Morning Mindfulness')).toBeInTheDocument();

    // Voice error shown but sub-plan tree still works
    expect(screen.getByText('Voice fetch failed')).toBeInTheDocument();
    expect(screen.getByTestId('sub-plan-tree')).toBeInTheDocument();
  });

  it('renders draft plan correctly', async () => {
    const draftPlan = {
      ...MOCK_PLAN,
      isPublished: false,
      visibility: 'private' as const,
    };

    mockAdminFetch.mockImplementation((path: string) => {
      if (path.includes('/admin/plans/plan-001') && !path.includes('tree') && !path.includes('voices')) {
        return Promise.resolve(draftPlan);
      }
      if (path.includes('/tree')) {
        return Promise.resolve({ ...MOCK_TREE, children: [] });
      }
      if (path.includes('/voices')) {
        return Promise.resolve([]);
      }
      return Promise.reject(new Error('Unknown path'));
    });

    const page = await AdminPlanDetailPage({
      params: Promise.resolve({ id: 'plan-001' }),
    });
    render(page);

    expect(screen.getByTestId('publish-toggle')).toHaveTextContent('draft');
    expect(screen.getByTestId('visibility-selector')).toHaveTextContent('private');
  });

  it('renders Back to Plans navigation link', async () => {
    mockAdminFetch.mockImplementation((path: string) => {
      if (path.includes('/admin/plans/plan-001') && !path.includes('tree') && !path.includes('voices')) {
        return Promise.resolve(MOCK_PLAN);
      }
      if (path.includes('/tree')) {
        return Promise.resolve(MOCK_TREE);
      }
      if (path.includes('/voices')) {
        return Promise.resolve(MOCK_VOICES);
      }
      return Promise.reject(new Error('Unknown path'));
    });

    const page = await AdminPlanDetailPage({
      params: Promise.resolve({ id: 'plan-001' }),
    });
    render(page);

    const backLink = screen.getByText(/Back to Plans/);
    expect(backLink).toBeInTheDocument();
    expect(backLink).toHaveAttribute('href', '/admin/plans');
  });

  it('has proper section headings for accessibility', async () => {
    mockAdminFetch.mockImplementation((path: string) => {
      if (path.includes('/admin/plans/plan-001') && !path.includes('tree') && !path.includes('voices')) {
        return Promise.resolve(MOCK_PLAN);
      }
      if (path.includes('/tree')) {
        return Promise.resolve(MOCK_TREE);
      }
      if (path.includes('/voices')) {
        return Promise.resolve(MOCK_VOICES);
      }
      return Promise.reject(new Error('Unknown path'));
    });

    const page = await AdminPlanDetailPage({
      params: Promise.resolve({ id: 'plan-001' }),
    });
    render(page);

    expect(screen.getByText('Plan Settings')).toBeInTheDocument();
    expect(screen.getByText('Sub-Plan Hierarchy')).toBeInTheDocument();
    expect(screen.getByText('Voice Renditions')).toBeInTheDocument();
  });
});
