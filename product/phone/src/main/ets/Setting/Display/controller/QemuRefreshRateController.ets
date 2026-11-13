/* Copyright (c) 2026 Harmony Contrib. SPDX-License-Identifier: Apache-2.0 */
import screen from '@ohos.screen';

export function mainScreen(screens: screen.Screen[]): screen.Screen {
  const candidates = screens.filter((item: screen.Screen) => item.sourceMode === screen.ScreenSourceMode.SCREEN_MAIN);
  if (candidates.length !== 1) throw new Error('Expected one actual main screen');
  const current = candidates[0];
  const ids: number[] = [];
  for (const mode of current.supportedModeInfo) {
    if (!Number.isInteger(mode.id) || mode.id < 0 || ids.includes(mode.id) ||
      !Number.isInteger(mode.width) || mode.width <= 0 || !Number.isInteger(mode.height) || mode.height <= 0 ||
      !Number.isInteger(mode.refreshRate) || mode.refreshRate <= 0) {
      throw new Error('Invalid actual screen mode');
    }
    ids.push(mode.id);
  }
  if (!Number.isInteger(current.activeModeIndex) || current.activeModeIndex < 0 ||
    current.activeModeIndex >= current.supportedModeInfo.length) throw new Error('Invalid active screen mode index');
  return current;
}

export function refreshChoices(current: screen.Screen): screen.ScreenModeInfo[] {
  const active = current.supportedModeInfo[current.activeModeIndex];
  if (active === undefined) throw new Error('Missing actual active mode');
  // A refresh-rate page must never implicitly change the resolution.
  return current.supportedModeInfo.filter((mode: screen.ScreenModeInfo) =>
    mode.width === active.width && mode.height === active.height);
}

export class QemuRefreshRateController {
  private changing: boolean = false;

  async read(): Promise<screen.Screen> {
    return mainScreen(await screen.getAllScreens());
  }

  async change(modeId: number): Promise<screen.Screen> {
    if (this.changing) throw new Error('Screen mode change is already pending');
    this.changing = true;
    try {
      const before = await this.read();
      if (!Number.isInteger(modeId) || !refreshChoices(before).some(
        (mode: screen.ScreenModeInfo) => mode.id === modeId)) {
        throw new Error('Requested refresh mode is not supported at the current resolution');
      }
      const modeIndex = before.supportedModeInfo.findIndex((mode: screen.ScreenModeInfo) => mode.id === modeId);
      if (before.activeModeIndex === modeIndex) return before;
      await before.setScreenActiveMode(modeIndex);
      const after = await this.read();
      if (after.id !== before.id || after.supportedModeInfo[after.activeModeIndex].id !== modeId) {
        throw new Error('Display service did not apply the requested refresh mode');
      }
      return after;
    } finally {
      this.changing = false;
    }
  }
}
