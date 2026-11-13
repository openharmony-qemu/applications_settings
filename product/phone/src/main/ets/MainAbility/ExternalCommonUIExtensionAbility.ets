/* Copyright (c) 2026 Harmony Contrib. SPDX-License-Identifier: Apache-2.0 */
import { UIExtensionAbility, UIExtensionContentSession, Want } from '@kit.AbilityKit';
import inputMethod from '@ohos.inputMethod';
import { AbilityContextManager } from '@ohos/settings.common/src/main/ets/ability/AbilityContextManager';
import { FontScaleUtils } from '@ohos/settings.common/src/main/ets/utils/FontScaleUtils';
import { LogUtil } from '@ohos/settings.common/src/main/ets/utils/LogUtil';
import { InputPushParam } from '../pages/input/controller/inputSettingController';

interface InputExtra {
  value: string;
  name: string;
}

interface InputRequest {
  extra: InputExtra;
}

interface InputSessionStorage {
  session: UIExtensionContentSession;
  inputRoute: string;
  inputConfig: InputPushParam;
}

// Public settings navigation opens UI only. It does not enable or switch an IME.
// Reuse the original Settings controllers and their permission checks.
export default class ExternalCommonUIExtensionAbility extends UIExtensionAbility {
  private activeSession: UIExtensionContentSession | undefined = undefined;

  onSessionCreate(want: Want, session: UIExtensionContentSession): void {
    if (this.activeSession !== undefined) {
      session.terminateSelf();
      return;
    }
    try {
      const route = want.uri;
      let config = new InputPushParam({ value: '', name: '' }, '');
      if (route === 'other_input_detail_settings') {
        const raw = want.parameters?.pushParam;
        if (want.parameters?.isParamJsonObject !== true || typeof raw !== 'string' ||
          raw.length === 0 || raw.length > 8192) {
          throw new Error('invalid input detail request');
        }
        const request = JSON.parse(raw) as InputRequest;
        if (request === null || typeof request !== 'object' || request.extra === null ||
          typeof request.extra !== 'object' || typeof request.extra.value !== 'string' ||
          typeof request.extra.name !== 'string' || request.extra.value.length === 0 ||
          request.extra.name.length === 0 || request.extra.value.length > 512 || request.extra.name.length > 512) {
          throw new Error('invalid input method identity');
        }
        const ime = inputMethod.getSetting().getAllInputMethodsSync().find(
          (item: inputMethod.InputMethodProperty) =>
            item.name === request.extra.value && item.id === request.extra.name);
        if (ime === undefined) {
          throw new Error('input method is not installed');
        }
        // Copy only verified identity and the installed label, never arbitrary caller configuration.
        config = new InputPushParam({ value: ime.name, name: ime.id }, ime.label ?? ime.name);
      } else if (route !== 'set_input') {
        throw new Error('unsupported settings route');
      }
      this.activeSession = session;
      AbilityContextManager.addContext(this.context);
      FontScaleUtils.setConfig(this.context.config.fontSizeScale as number);
      const storage = new LocalStorage({ session: session, inputRoute: route,
        inputConfig: config } as InputSessionStorage);
      session.loadContent('pages/input/ExternalInputSettings', storage);
    } catch (error) {
      LogUtil.error('ExternalCommonUIExtensionAbility: failed to open input settings');
      this.releaseSession(session);
      session.terminateSelf();
    }
  }

  private releaseSession(session: UIExtensionContentSession): void {
    if (this.activeSession === session) {
      AbilityContextManager.removeContext(this.context);
      this.activeSession = undefined;
    }
  }

  onSessionDestroy(session: UIExtensionContentSession): void {
    this.releaseSession(session);
  }
}
