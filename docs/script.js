(function () {
  'use strict';

  var copyButton = document.getElementById('copy-command');
  var commandElement = document.getElementById('install-command');
  var statusElement = document.getElementById('copy-status');

  if (!copyButton || !commandElement || !statusElement) {
    return;
  }

  var originalLabel = 'Copiar comando';
  var resetTimer;

  function fallbackCopy(text) {
    var textArea = document.createElement('textarea');
    textArea.value = text;
    textArea.setAttribute('readonly', '');
    textArea.style.position = 'fixed';
    textArea.style.opacity = '0';
    document.body.appendChild(textArea);
    textArea.select();
    var copied = document.execCommand('copy');
    document.body.removeChild(textArea);
    return copied;
  }

  function showResult(success) {
    var label = copyButton.querySelector('.copy-label');
    clearTimeout(resetTimer);

    if (success) {
      copyButton.classList.add('copied');
      label.textContent = 'Copiado!';
      statusElement.textContent = 'Comando copiado. Agora cole no Windows PowerShell.';
    } else {
      copyButton.classList.remove('copied');
      label.textContent = 'Copie manualmente';
      statusElement.textContent = 'N\u00e3o foi poss\u00edvel copiar automaticamente. Selecione o comando e copie.';
    }

    resetTimer = window.setTimeout(function () {
      copyButton.classList.remove('copied');
      label.textContent = originalLabel;
    }, 2600);
  }

  copyButton.addEventListener('click', async function () {
    var command = commandElement.textContent.trim();

    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(command);
        showResult(true);
        return;
      }

      showResult(fallbackCopy(command));
    } catch (error) {
      showResult(fallbackCopy(command));
    }
  });
}());
