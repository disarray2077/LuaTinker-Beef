if (typeof window !== 'undefined') {
  const status = document.getElementById('status');
  const output = document.getElementById('output');
  const demo = document.getElementById('demo');
  const run = document.getElementById('run');
  const stop = document.getElementById('stop');
  const requested = new URLSearchParams(location.search).get('run');
  const selected = Array.from(demo.options).some(option => option.value === requested) ? requested : null;
  if (selected) demo.value = selected;

  function appendOutput(message) {
    output.textContent += message + '\n';
    output.scrollTop = output.scrollHeight;
  }

  Module['canvas'] = document.getElementById('canvas');
  Module['canvas'].addEventListener('contextmenu', event => event.preventDefault());
  Module['print'] = appendOutput;
  Module['printErr'] = appendOutput;
  Module['setStatus'] = message => { if (message) status.textContent = message; };
  Module['onAbort'] = reason => { status.textContent = 'Failed: ' + reason; };
  Module['onRuntimeInitialized'] = () => {
    run.disabled = false;
    status.textContent = 'Ready';
    if (!selected) return;
    stop.disabled = false;
    status.textContent = 'Running ' + selected;
    Module['canvas'].focus();
    callMain(['/templates/' + selected]);
  };

  run.addEventListener('click', () => {
    const url = new URL(location.href);
    url.searchParams.set('run', demo.value);
    location.href = url;
  });
  stop.addEventListener('click', () => {
    const url = new URL(location.href);
    url.searchParams.delete('run');
    location.href = url;
  });
}
