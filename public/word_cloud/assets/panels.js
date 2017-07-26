'use strict';

/* global View, _, __, GOOGLE_CLIENT_ID, GO2 */

var PanelView = function PanelView() {
};
PanelView.prototype = new View();
PanelView.prototype.beforeShow = function pv_beforeShow() {
  this.menuItemElement.parentNode.className += ' active';
  this.dialog.selectionElement.selectedIndex = this.selectionIndex;
};
PanelView.prototype.afterShow = function pv_afterShow() {
  var el = this.element.querySelector('input, button, select, textarea');
  if (el) {
    el.focus();
  }
};
PanelView.prototype.beforeHide = function pv_beforeHide() {
  this.menuItemElement.parentNode.className =
    this.menuItemElement.parentNode.className.replace(/ active/g, '');
};

var ExamplePanelView = function ExamplePanelView(opts) {
  this.load(opts, {
    name: 'example',
    element: 'wc-panel-example',
    supportMsgElement: 'wc-panel-example-support-msg'
  });

  this.checked = false;
};
ExamplePanelView.prototype = new PanelView();
ExamplePanelView.prototype.beforeShow = function epv_beforeShow() {
  PanelView.prototype.beforeShow.apply(this, arguments);

  if (this.checked) {
    return;
  }

  if (!this.dialog.app.isFullySupported) {
    this.supportMsgElement.removeAttribute('hidden');
  }

  this.checked = true;
};
ExamplePanelView.prototype.submit = function epv_submit() {
  var els = this.element.querySelectorAll('[name="example"]');
  for (var el in els) {
    if (els[el].checked) {
      this.dialog.submit('#' + els[el].value);
      break;
    }
  }
};

var FacebookPanelView = function FacebookPanelView(opts) {
  this.load(opts, {
    name: 'facebook',
    element: 'wc-panel-facebook',
    inputElement: 'wc-panel-facebook-title'
  });
};
FacebookPanelView.prototype = new PanelView();
FacebookPanelView.prototype.submit = function wpv_submit() {
  var el = this.inputElement;

  if (!el.value) {
    return;
  }

  // XXX maybe provide a <select> of largest Facebooks here.
  // (automatically from this table or manually)
  // https://meta.wikimedia.org/wiki/List_of_Facebooks/Table

  this.dialog.submit('#facebook:' + el.value);
};