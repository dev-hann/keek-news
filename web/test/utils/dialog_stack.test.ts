import { describe, expect, it } from 'vitest';
import { dialogClosed, dialogOpened, holdsFocus } from '../../src/utils/dialog_stack';

const element = (): Element => ({}) as Element;

describe('the stack of open dialogs', () => {
  it('gives the focus to the frontmost dialog only', () => {
    const viewer = element();
    const sheet = element();
    dialogOpened(viewer);
    expect(holdsFocus(viewer)).toBe(true);

    dialogOpened(sheet);
    expect(holdsFocus(sheet)).toBe(true);
    expect(holdsFocus(viewer)).toBe(false);

    dialogClosed(sheet);
    expect(holdsFocus(viewer)).toBe(true);
    expect(holdsFocus(sheet)).toBe(false);

    dialogClosed(viewer);
    expect(holdsFocus(viewer)).toBe(false);
  });

  it('closing a dialog that is not the frontmost leaves the frontmost as it is', () => {
    const viewer = element();
    const sheet = element();
    dialogOpened(viewer);
    dialogOpened(sheet);

    dialogClosed(viewer);

    expect(holdsFocus(sheet)).toBe(true);
    dialogClosed(sheet);
  });

  it('closing a dialog that never opened, or twice, changes nothing', () => {
    const dialog = element();
    dialogOpened(dialog);
    dialogClosed(dialog);
    dialogClosed(dialog);

    expect(holdsFocus(dialog)).toBe(false);
  });
});
