import React, { useEffect, useState } from 'react';
import { Button, Text, View } from 'react-native';
import { Performance } from '@ios-performance/react-native';

const fakeDelay = (milliseconds: number) => new Promise<void>((resolve) => setTimeout(resolve, milliseconds));

export function LoginDemo() {
  const [screen, setScreen] = useState<'login' | 'home'>('login');
  const [homeReady, setHomeReady] = useState(false);

  useEffect(() => {
    void (async () => {
      await Performance.start('LOGIN');
      await Performance.mark('LOGIN_SCREEN_VISIBLE');
    })();
  }, []);

  async function login() {
    await Performance.mark('LOGIN_TAP');
    await Performance.mark('AUTH_API_START', 'network');
    await Performance.start('AUTH_API');
    await fakeDelay(300); // illustrative fake API wait; no network request is made
    await Performance.end('AUTH_API');
    await Performance.mark('AUTH_API_END', 'network');
    await Performance.mark('NAVIGATION_START', 'navigation');
    setScreen('home');
  }

  useEffect(() => {
    if (screen !== 'home') return;
    void (async () => {
      await Performance.mark('HOME_VISIBLE', 'render');
      await Performance.mark('HOME_DATA_START', 'network');
      await Performance.start('HOME_DATA');
      await fakeDelay(200); // illustrative fake data wait; no network request is made
      await Performance.end('HOME_DATA');
      await Performance.mark('HOME_DATA_END', 'network');
      setHomeReady(true);
    })();
  }, [screen]);

  useEffect(() => {
    if (!homeReady) return;
    void (async () => {
      await Performance.mark('HOME_READY', 'render');
      await Performance.end('LOGIN');
    })();
  }, [homeReady]);

  return screen === 'login'
    ? <View><Text>Example login</Text><Button title="Login" onPress={() => void login()} /></View>
    : <View><Text>{homeReady ? 'Example home ready' : 'Loading home'}</Text></View>;
}
