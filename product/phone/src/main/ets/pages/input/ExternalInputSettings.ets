/* Copyright (c) 2026 Harmony Contrib. SPDX-License-Identifier: Apache-2.0 */
import { UIExtensionContentSession } from '@kit.AbilityKit';
import { PushParam } from '@ohos/settings.common/src/main/ets/core/controller/Controller';
import { NavEntryKey } from '@ohos/settings.common/src/main/ets/utils/Consts';
import { InputPushParam } from './controller/inputSettingController';
import { InputSettings } from './InputSettings';
import { OtherInputDetailSettings } from './otherInputDetailSettings';
import { UiExtensionList } from './uiExtensionList';

@Entry({ useSharedStorage: true })
@Component
struct ExternalInputSettings {
  @Provide('pathInfos') pathInfos: NavPathStack = new NavPathStack();
  @LocalStorageProp('inputRoute') inputRoute: string = '';
  @LocalStorageProp('inputConfig') inputConfig: InputPushParam = new InputPushParam({ value: '', name: '' }, '');
  private session: UIExtensionContentSession | undefined = undefined;

  aboutToAppear(): void {
    this.session = this.getUIContext().getSharedLocalStorage()?.get<UIExtensionContentSession>('session');
    // The extension admits only these two external entry routes.
    if (this.inputRoute !== NavEntryKey.INPUT_ENTRY && this.inputRoute !== NavEntryKey.OTHER_INPUT_DETAIL_SETTINGS) {
      this.session?.terminateSelf();
      return;
    }
    this.pathInfos.pushPath(new NavPathInfo(this.inputRoute, new PushParam(this.inputConfig), () => {
      this.session?.terminateSelf();
    }), false);
  }

  @Builder
  destination(name: string, param: Object) {
    if (name === NavEntryKey.INPUT_ENTRY) {
      InputSettings({ params: param as PushParam });
    } else if (name === NavEntryKey.OTHER_INPUT_DETAIL_SETTINGS) {
      OtherInputDetailSettings({ params: param as PushParam });
    } else if (name === NavEntryKey.INPUT_UIEXTENSION_LIST) {
      UiExtensionList({ params: param as PushParam });
    }
  }

  build() {
    Navigation(this.pathInfos) {
    }
    .hideNavBar(true)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.destination)
  }

  onBackPress(): boolean {
    if (this.pathInfos.size() > 1) {
      this.pathInfos.pop();
    } else {
      this.session?.terminateSelf();
    }
    return true;
  }
}
