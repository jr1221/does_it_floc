// Get current Url using chrome.tabs API, and give the callback

async function getCurrentUrl() {
      let queryOptions = { active: true, currentWindow: true };
      await chrome.tabs.query(queryOptions, currentQueryCallback);
      return true;
}

// Callback for above chrome API usage, which calls the JS interop function name, passing in the url

function currentQueryCallback(tab) {
   dartCallWithUrl(tab[0].url);
}
