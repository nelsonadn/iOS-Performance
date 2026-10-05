import { Component, OnInit } from '@angular/core';
import { NavController } from '@ionic/angular';
import { Performance } from '@ios-performance/capacitor';

const fakeDelay = (milliseconds: number) => new Promise<void>((resolve) => setTimeout(resolve, milliseconds));

@Component({ selector: 'app-login-demo', template: '<ion-button (click)="login()">Login</ion-button>' })
export class LoginDemoPage implements OnInit {
  constructor(private readonly nav: NavController) {}

  async ngOnInit() {
    await Performance.start({ name: 'LOGIN' });
    await Performance.mark({ name: 'LOGIN_SCREEN_VISIBLE' });
  }

  async login() {
    await Performance.mark({ name: 'LOGIN_TAP' });
    await Performance.mark({ name: 'AUTH_API_START', category: 'network' });
    await Performance.start({ name: 'AUTH_API' });
    await fakeDelay(300); // illustrative fake API wait; no network request is made
    await Performance.end({ name: 'AUTH_API' });
    await Performance.mark({ name: 'AUTH_API_END', category: 'network' });
    await Performance.mark({ name: 'NAVIGATION_START', category: 'navigation' });
    await this.nav.navigateRoot('/home');
  }
}

@Component({ selector: 'app-home-demo', template: '<ion-content>{{ ready ? "Example home ready" : "Loading home" }}</ion-content>' })
export class HomeDemoPage implements OnInit {
  ready = false;

  async ngOnInit() {
    await Performance.mark({ name: 'HOME_VISIBLE', category: 'render' });
    await Performance.mark({ name: 'HOME_DATA_START', category: 'network' });
    await Performance.start({ name: 'HOME_DATA' });
    await fakeDelay(200); // illustrative fake data wait; no network request is made
    await Performance.end({ name: 'HOME_DATA' });
    await Performance.mark({ name: 'HOME_DATA_END', category: 'network' });
    this.ready = true;
    await Performance.mark({ name: 'HOME_READY', category: 'render' });
    await Performance.end({ name: 'LOGIN' });
  }
}
