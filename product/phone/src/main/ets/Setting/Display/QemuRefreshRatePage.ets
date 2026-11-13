/* Copyright (c) 2026 Harmony Contrib. SPDX-License-Identifier: Apache-2.0 */
import screen from '@ohos.screen';
import { PageLoader } from '@ohos/settings.common/src/main/ets/framework/common/PageLoader';
import { PageType, SettingPageModel } from '@ohos/settings.common/src/main/ets/framework/model/SettingPageModel';
import { QemuRefreshRateController, refreshChoices } from './controller/QemuRefreshRateController';

@Component
struct QemuRefreshRateSettings {
  @State private modes: screen.ScreenModeInfo[] = [];
  @State private activeMode: number = -1;
  @State private pending: boolean = false;
  @State private failure: string = '';
  private controller: QemuRefreshRateController = new QemuRefreshRateController();
  private generation: number = 0;

  private async load(modeId?: number): Promise<void> {
    if (this.pending) return;
    const generation = ++this.generation;
    this.pending = true;
    this.failure = '';
    try {
      const current = modeId === undefined ? await this.controller.read() : await this.controller.change(modeId);
      if (generation !== this.generation) return;
      this.modes = refreshChoices(current);
      this.activeMode = current.supportedModeInfo[current.activeModeIndex].id;
    } catch (error) {
      if (generation === this.generation) {
        this.failure = 'Display service: ' + String(error);
      }
    } finally {
      if (generation === this.generation) this.pending = false;
    }
  }

  build() {
    NavDestination() {
      Column({ space: 16 }) {
        ForEach(this.modes, (mode: screen.ScreenModeInfo) => {
          Row({ space: 16 }) {
            Text(mode.refreshRate.toString() + ' Hz').id('qemu-refresh-rate-' + mode.id.toString())
            Blank()
            Radio({ value: mode.id.toString(), group: 'actual-screen-refresh-rate' })
              .checked(this.activeMode === mode.id)
              .enabled(!this.pending)
              .onChange((checked: boolean) => { if (checked) this.load(mode.id); })
          }.width('100%').padding(16)
        }, (mode: screen.ScreenModeInfo) => mode.id.toString())
        if (this.pending) { LoadingProgress().width(32).height(32) }
        if (this.failure.length > 0) { Text(this.failure).id('qemu-refresh-rate-error') }
      }.padding(16).width('100%')
    }
    .title($r('app.string.screen_refresh_rate_title'))
    .backgroundColor($r('sys.color.ohos_id_color_titlebar_sub_bg'))
    .onShown(() => { this.pending = false; this.load(); })
    .onHidden(() => { this.generation++; })
  }
}

@Builder
function refreshRateBuilder(param: object): void {
  QemuRefreshRateSettings();
}

function refreshRatePage(): SettingPageModel {
  return {
    id: 'QemuRefreshRate',
    url: 'screen_refresh_rate_entry',
    type: PageType.PAGE_TYPE_CUSTOM,
    title: $r('app.string.screen_refresh_rate_title'),
    hdsNavDestinationUx: false
  };
}

PageLoader.load('screen_refresh_rate_entry', {
  configGenerator: refreshRatePage,
  pageBuilder: wrapBuilder(refreshRateBuilder),
});
