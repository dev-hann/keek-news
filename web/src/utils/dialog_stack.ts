/**
 * The modal dialogs that are open, the frontmost last. A dialog traps the
 * focus only while it is the frontmost: a sheet opened from an image viewer
 * owns the focus until it closes, and the trap of the viewer under it must
 * not pull the focus back, or the two would pass it to each other for good.
 */
const dialogs: Element[] = [];

/** Says that `dialog` is open. It goes in front of the ones already open. */
export function dialogOpened(dialog: Element): void {
  dialogs.push(dialog);
}

/** Says that `dialog` closed. Whatever it trapped goes to the one under it. */
export function dialogClosed(dialog: Element): void {
  const at = dialogs.lastIndexOf(dialog);
  if (at >= 0) dialogs.splice(at, 1);
}

/** Whether `dialog` is the frontmost one: the only one that may hold the focus. */
export function holdsFocus(dialog: Element): boolean {
  return dialogs[dialogs.length - 1] === dialog;
}
