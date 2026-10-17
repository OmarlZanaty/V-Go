(function () {
  'use strict';
  var nav = document.getElementById('mainNav');
  function onScroll() { if (nav) nav.classList.toggle('scrolled', window.scrollY > 40); }
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
  var toggle = document.getElementById('menuToggle');
  var menu = document.getElementById('nav');
  function closeMenu() { if (menu) menu.classList.remove('open'); if (toggle) toggle.setAttribute('aria-expanded', 'false'); }
  if (toggle) toggle.addEventListener('click', function () {
    var open = menu.classList.toggle('open'); toggle.setAttribute('aria-expanded', String(open));
  });
  if (menu) menu.querySelectorAll('a').forEach(function (a) { a.addEventListener('click', closeMenu); });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && menu && menu.classList.contains('open')) { closeMenu(); toggle.focus(); } });
  var motion = window.matchMedia('(prefers-reduced-motion: reduce)');
  if (!motion.matches && 'IntersectionObserver' in window) {
    document.body.classList.add('motion-ready');
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) { if (entry.isIntersecting) { entry.target.classList.remove('pending'); observer.unobserve(entry.target); } });
    }, { threshold: .08 });
    document.querySelectorAll('.reveal').forEach(function (el) { el.classList.add('pending'); observer.observe(el); });
    motion.addEventListener('change', function () { if (motion.matches) { document.querySelectorAll('.pending').forEach(function (el) { el.classList.remove('pending'); }); observer.disconnect(); } });
  }
  var year = document.getElementById('year'); if (year) year.textContent = new Date().getFullYear();
  var contact = document.getElementById('privacyEmail');
  if (contact && window.VGO_CONFIG.CONTACT_EMAIL) {
    contact.href = 'mailto:' + window.VGO_CONFIG.CONTACT_EMAIL;
    contact.textContent = window.VGO_CONFIG.CONTACT_EMAIL;
    contact.hidden = false;
  }
})();
