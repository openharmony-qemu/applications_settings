/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
 
import Want from '@ohos.app.ability.Want';
import config from '@ohos.accessibility.config';
import { ServiceExtensionAbility } from '@kit.AbilityKit';
import { LogUtil } from '@ohos/settings.common/src/main/ets/utils/LogUtil';
import { SettingsDataUtils } from '@ohos/settings.common/src/main/ets/utils/SettingsDataUtils';
import { HiSysEventUtil } from '@ohos/settings.common/src/main/ets/systemEvent/HiSysEventUtil';
import { HiSysAccessibilityEventGroup } from '@ohos/settings.common/src/main/ets/systemEvent/BehaviorEventConsts';
import { CLICK_SWITCH_OFF } from '../constant/Constants';
import { IgnoreRepeatedStateModel } from '../utils/AccessibilityIgnoreRepeatedModel';

/* instrument ignore file */
const TAG: string = 'IgnoreRepeatClickService';
const DISABLE_IGNORE_REPEAT_CLICK_SWITCH: string = 'disableIgnoreRepeatClick';
const DISABLE_IGNORE_REPEAT_CLICK_NOTIFICATION: string = 'disableNotificaiton';
const DISABLE_IGNORE_REPEAT_CLICK_NOTIFICATION_KEY: string = 'ignore_repeat_click_notification';
const REOPEN_TRANSITION_ANIMATIONS_SWITCH: string = 'reOpenTransitionAnimations';
const DISABLE_TRANSITION_ANIMATIONS_NOTIFICATION: string = 'disableTransitionAnimationsNotification';
const DISABLE_TRANSITION_ANIMATIONS_NOTIFICATION_KEY: string = 'transition_animations_notification';
 
export default class IgnoreRepeatClickService extends ServiceExtensionAbility {
  private requestQueue: Promise<void> = Promise.resolve();
  private active: boolean = true;
  private lifecycle: number = 0;
  private latestStartId: number = 0;

  async onCreate(want: Want) {
    this.active = true;
    this.latestStartId = 0;
    ++this.lifecycle;
    LogUtil.showInfo(TAG, 'onCreate');
  }

  onRequest(want: Want, startId: number): void {
    if (!this.active) {
      return;
    }
    const lifecycle: number = this.lifecycle;
    this.latestStartId = startId;
    const action: string = want?.action?.toString() ?? '';
    LogUtil.showInfo(TAG, `onRequest abilityName:${want?.abilityName} bundleName:${want?.bundleName} action:${action}`);
    // Serialize notification actions until the real configuration operation completes.
    this.requestQueue = this.requestQueue.then(() => this.handleRequest(action, lifecycle))
      .then(() => this.stopIfIdle(startId, lifecycle));
  }

  private async stopIfIdle(startId: number, lifecycle: number): Promise<void> {
    if (!this.active || lifecycle !== this.lifecycle || this.latestStartId !== startId) {
      return;
    }
    try {
      const context = this.context;
      const stopped: boolean = await context.terminateSelfIfStartId(startId);
      if (this.active && lifecycle === this.lifecycle) {
        LogUtil.info(`${TAG} conditional idle stop startId:${startId} accepted:${stopped}`);
      }
      // A newer AMS request makes stopped=false. Keep this queue usable for it.
    } catch (e) {
      if (this.active && lifecycle === this.lifecycle) {
        LogUtil.error(`${TAG} conditional idle stop failed startId:${startId} code:${e?.code} message:${e?.message}`);
      }
    }
  }

  private async handleRequest(action: string, lifecycle: number): Promise<void> {
    if (!this.active || lifecycle !== this.lifecycle) {
      return;
    }
    try {
      if (action === DISABLE_IGNORE_REPEAT_CLICK_SWITCH) {
        await this.disableIgnoreRepeatClickSwitch(lifecycle);
      } else if (action === DISABLE_IGNORE_REPEAT_CLICK_NOTIFICATION) {
        this.disableIgnoreRepeatClickNotification();
      } else if (action === REOPEN_TRANSITION_ANIMATIONS_SWITCH) {
        await this.reopenTransitionAnimationsSwitch(lifecycle);
      } else if (action === DISABLE_TRANSITION_ANIMATIONS_NOTIFICATION) {
        this.disableTransitionAnimationsNotification();
      } else {
        LogUtil.warn(`${TAG} no suitable action`);
      }
    } catch (e) {
      if (this.active && lifecycle === this.lifecycle) {
        LogUtil.error(`${TAG} action:${action} failed, code: ${e?.code} message: ${e?.message}`);
      }
    }
  }


  onDisconnect(want: Want) {
    LogUtil.showInfo(TAG, 'onDisconnect');
  }
 
  onDestroy() {
    this.active = false;
    ++this.lifecycle;
    LogUtil.showInfo(TAG, 'onDestroy');
  }
 
  private async disableIgnoreRepeatClickSwitch(lifecycle: number): Promise<void> {
    await config.ignoreRepeatClick.set(false);
    if (!this.active || lifecycle !== this.lifecycle) {
      return;
    }
    IgnoreRepeatedStateModel.getInstance().ignoreRepeatClick = false;
    HiSysEventUtil.reportDefaultBehaviorEventByUE(
      HiSysAccessibilityEventGroup.IGNORE_REPEAT_TOUCHES_SWITCH, 'off');
    LogUtil.info(`${TAG} ignoreRepeatClick set off success`);
  }
 
  private disableIgnoreRepeatClickNotification() {
    SettingsDataUtils.setSecureValue(DISABLE_IGNORE_REPEAT_CLICK_NOTIFICATION_KEY, CLICK_SWITCH_OFF);
  }

  private async reopenTransitionAnimationsSwitch(lifecycle: number): Promise<void> {
    await config.animationOff.set(false);
    if (!this.active || lifecycle !== this.lifecycle) {
      return;
    }
    HiSysEventUtil.reportDefaultBehaviorEventByUE(
      HiSysAccessibilityEventGroup.TRANSITION_ANIMATIONS_STATE, 'on');
    LogUtil.info(`${TAG} animationOff set false success`);
  }
 
  private disableTransitionAnimationsNotification() {
    SettingsDataUtils.setSecureValue(DISABLE_TRANSITION_ANIMATIONS_NOTIFICATION_KEY, CLICK_SWITCH_OFF);
  }
}
