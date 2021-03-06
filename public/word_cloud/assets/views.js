'use strict';

/* global __ */

// Super light-weight prototype-based objects and inherences
var View = function View() { };
View.prototype.load = function v_load(properties, defaultProperties) {
  properties = properties || {};
  for (var name in defaultProperties) {
    if (name in this) {
      break;
    }

    this[name] = (name in properties) ?
      properties[name] : defaultProperties[name];

    if (name === 'element' || /Element$/.test(name)) {
      this[name] = (typeof this[name] === 'string') ?
        document.getElementById(this[name]) : this[name];
    }
  }
};
View.prototype.show = function v_show(currentState, nextState) {
  if (('beforeShow' in this) &&
      this.beforeShow.apply(this, arguments) === false) {
    return false;
  }

  this.element.removeAttribute('hidden');

  if ('afterShow' in this) {
    this.afterShow.apply(this, arguments);
  }
  return true;
};
View.prototype.hide = function v_hide(currentState, nextState) {
  if (('beforeHide' in this) &&
      this.beforeHide.apply(this, arguments) === false) {
    return false;
  }

  this.element.setAttribute('hidden', true);

  if ('afterHide' in this) {
    this.afterHide.apply(this, arguments);
  }
  return true;
};

var LoadingView = function LoadingView(opts) {
  this.load(opts, {
    name: 'loading',
    element: 'wc-loading',
    labelElement: 'wc-loading-label'
  });

  this.stringIds = [
    'downloading',
    'loading',
    'analyzing',
    'no_data',
    'no_list_output'
  ];
};
LoadingView.prototype = new View();
LoadingView.prototype.LABEL_DOWNLOADING = 0;
LoadingView.prototype.LABEL_LOADING = 1;
LoadingView.prototype.LABEL_ANALYZING = 2;
LoadingView.prototype.LABEL_ERROR_DATA = 3;
LoadingView.prototype.LABEL_ERROR_LIST = 4;
LoadingView.prototype.beforeShow = function l_beforeShow(state, nextState) {
  if (nextState === this.app.UI_STATE_ERROR_WITH_DASHBOARD) {
    this.element.className = 'error';
  } else {
    this.element.className = '';
  }
};
LoadingView.prototype.updateLabel = function l_updateLabel(stringId) {
  if (!this.stringIds[stringId]) {
    throw 'Undefined stringId ' + stringId;
  }

  this.labelElement.setAttribute('data-l10n-id', this.stringIds[stringId]);
  __(this.labelElement);
};

var ListDialogView = function ListDialogView(opts) {
  this.load(opts, {
    name: 'list-dialog',
    element: 'wc-list-dialog',
    textElement: 'wc-list-edit',
    cancelBtnElement: 'wc-list-cancel-btn',
    confirmBtnElement: 'wc-list-confirm-btn'
  });

  this.cancelBtnElement.addEventListener('click', this);
  this.confirmBtnElement.addEventListener('click', this);
};
ListDialogView.prototype = new View();
ListDialogView.prototype.beforeShow = function ldv_beforeShow() {
  this.textElement.value = this.app.data.list.map(function mapItem(item) {
    return item[1] + '\t' + item[0];
  }).join('\n');
};
ListDialogView.prototype.afterShow = function ldv_afterShow() {
  this.textElement.focus();
};
ListDialogView.prototype.handleEvent = function ldv_handleEvent(evt) {
  switch (evt.target) {
    case this.confirmBtnElement:
      this.submit();

      break;

    case this.cancelBtnElement:
      this.close();

      break;
  }
};
ListDialogView.prototype.submit = function ldv_submit() {
  var el = this.textElement;
  var hash;
  if (window.btoa) {
    // Protect the encoded string with base64 to workaround Safari bug,
    // which improve sharability of the URL.
    hash = '#base64-list:' +
      window.btoa(unescape(encodeURIComponent(el.value)));
  } else {
    hash = '#list:' + encodeURIComponent(el.value);
  }

  var hashPushed = this.app.pushUrlHash(hash);
  if (!hashPushed) {
    // The hash is too long and is being rejected in IE.
    // let's use the short hash instead.
    this.app.pushUrlHash('#list');
  }
};
ListDialogView.prototype.close = function ldv_close() {
  this.app.switchUIState(this.app.UI_STATE_DASHBOARD);
};

var AboutDialogView = function AboutDialogView(opts) {
  this.load(opts, {
    name: 'about-dialog',
    element: 'wc-about-dialog',
    donateElement: 'wc-about-donate',
    donateContentElement: 'wc-about-donate-content',
    contentElement: 'wc-about-content',
    closeBtnElement: 'wc-about-close-btn'
  });

  this.loaded = false;

  this.closeBtnElement.addEventListener('click', this);
  this.contentElement.addEventListener('click', this);
  this.donateContentElement.addEventListener('submit', this);
  document.addEventListener('localized', this);
};
AboutDialogView.prototype = new View();
AboutDialogView.prototype.beforeShow = function adv_beforeShow() {
  this.app.logAction('AboutDialogView::view');

  this.loaded = true;
  var lang = document.documentElement.lang;
  this.loadContent(lang, true);
};
AboutDialogView.prototype.loadContent = function adv_loadContent(lang, first) {
  // Everything would be a *lot* easier
  // if we could have seamless iframe here...
  var iframe = document.createElement('iframe');
  iframe.src = 'about.' + lang + '.html';
  this.contentElement.appendChild(iframe);

  iframe.onload = (function contentLoaded() {
    // Import nodes to this document
    var content = document.importNode(
      iframe.contentWindow.document.body, true);

    // Create a document fragment; move all the children to it.
    var docFrag = document.createDocumentFragment();
    while (content.firstElementChild) {
      docFrag.appendChild(content.firstElementChild);
    }

    // Append the children to the container.
    var container = this.contentElement;
    while (container.firstChild) {
      container.removeChild(container.firstChild);
    }
    container.appendChild(docFrag);
  }).bind(this);

  if (first) {
    iframe.onerror = (function contentLoadError() {
      this.loaded = false;
      if (!this.element.hasAttribute('hidden')) {
        this.app.switchUIState(this.app.UI_STATE_SOURCE_DIALOG);
      }
    }).bind(this);
  }

  if (window.DONATE_HTML) {
    this.donateElement.removeAttribute('hidden');
    this.donateContentElement.innerHTML =
      window.DONATE_HTML.replace(/%lang/, lang.replace(/-/, '_'));
  }
};
AboutDialogView.prototype.handleEvent = function adv_handleEvent(evt) {
  if (evt.type === 'localized') {
    this.loaded = false;

    return;
  }

  switch (evt.currentTarget) {
    case this.contentElement:
      if (evt.target.tagName !== 'A') {
        break;
      }

      evt.preventDefault();
      window.open(evt.target.href);
      this.app.logAction('AboutDialogView::externalLink', evt.target.href);

      break;

    case this.donateContentElement:
      this.app.logAction('AboutDialogView::donateLink');

      break;

    case this.closeBtnElement:
      this.close();

      break;
  }
};
AboutDialogView.prototype.close = function adv_close() {
  this.app.switchUIState(this.app.UI_STATE_SOURCE_DIALOG);
};