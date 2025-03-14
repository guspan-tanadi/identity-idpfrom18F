import { forceRedirect } from '@18f/identity-url';
import { requestSessionStatus, extendSession } from '@18f/identity-session';
import type { SessionStatus } from '@18f/identity-session';
import type { CountdownElement } from '@18f/identity-countdown/countdown-element';
import type { ModalElement } from '@18f/identity-modal';

const warningEl = document.getElementById('session-timeout-cntnr');

const defaultTime = '60';

const frequency = parseInt(warningEl?.dataset.frequency || defaultTime, 10) * 1000;
const warning = parseInt(warningEl?.dataset.warning || defaultTime, 10) * 1000;
const start = parseInt(warningEl?.dataset.start || defaultTime, 10) * 1000;
const timeoutURL = warningEl?.dataset.timeoutUrl!;
const sessionsURL = warningEl?.dataset.sessionsUrl!;

const modal = document.querySelector<ModalElement>('lg-modal.session-timeout-modal')!;
const keepaliveButton = document.getElementById('session-keepalive-btn')!;
const countdownEls: NodeListOf<CountdownElement> = modal.querySelectorAll('lg-countdown');

function success({ isLive, timeout }: SessionStatus) {
  if (!isLive) {
    if (timeoutURL) {
      forceRedirect(timeoutURL);
    }
    return;
  }

  const timeRemaining = timeout.valueOf() - Date.now();
  const showWarning = timeRemaining < warning;
  if (showWarning) {
    modal.show();
    countdownEls.forEach((countdownEl) => {
      countdownEl.expiration = timeout;
      countdownEl.start();
    });
  }

  const nextPingTimeout =
    timeRemaining > 0 && timeRemaining < frequency ? timeRemaining : frequency;

  // Disable reason: circular dependency between ping and success
  // eslint-disable-next-line @typescript-eslint/no-use-before-define
  setTimeout(ping, nextPingTimeout);
}

const ping = () => requestSessionStatus(sessionsURL).then(success);

function keepalive(event: MouseEvent) {
  event.preventDefault();
  modal.hide();
  countdownEls.forEach((countdownEl) => countdownEl.stop());
  extendSession(sessionsURL);
}

keepaliveButton.addEventListener('click', keepalive);
setTimeout(ping, start);
