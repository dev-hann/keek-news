// @vitest-environment jsdom
import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { AppBar } from '../../src/widgets/app_bar';

describe('AppBar', () => {
  it('names the screen with plain text', () => {
    render(<AppBar title="웃긴대학" />);

    const title = screen.getByRole('heading', { level: 1, name: '웃긴대학' });
    expect(title.querySelector('button, a')).toBeNull();
    expect(screen.queryByRole('button')).toBeNull();
  });

  it('has a back arrow only where there is somewhere to go back to', () => {
    const onBack = vi.fn();

    render(<AppBar title="설정" onBack={onBack} />);

    fireEvent.click(screen.getByRole('button', { name: '뒤로' }));
    expect(onBack).toHaveBeenCalledTimes(1);
  });

  it('shows the actions it is given', () => {
    render(
      <AppBar
        title="웃긴대학"
        actions={
          <button type="button" aria-label="설정">
            settings
          </button>
        }
      />
    );

    expect(screen.getByRole('button', { name: '설정' })).toBeTruthy();
  });
});
