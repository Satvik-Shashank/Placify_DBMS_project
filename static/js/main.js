/* Placify – main.js */

// ─── Feather Icons ────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  if (typeof feather !== 'undefined') feather.replace({ width: 16, height: 16 });

  initSidebar();
  initModals();
  initAlertDismiss();
  initActiveNav();
  initTableSearch();
  highlightCurrentStat();
});

// ─── Sidebar toggle (mobile) ──────────────────────────────────────────────────
function initSidebar() {
  const toggle  = document.getElementById('sidebarToggle');
  const sidebar = document.querySelector('.sidebar');
  if (!toggle || !sidebar) return;

  toggle.addEventListener('click', () => sidebar.classList.toggle('open'));

  // Close if clicking outside
  document.addEventListener('click', (e) => {
    if (sidebar.classList.contains('open') &&
        !sidebar.contains(e.target) &&
        !toggle.contains(e.target)) {
      sidebar.classList.remove('open');
    }
  });
}

// ─── Modals ───────────────────────────────────────────────────────────────────
function initModals() {
  // Open
  document.querySelectorAll('[data-modal]').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-modal');
      openModal(id);
    });
  });

  // Close via backdrop click or close button
  document.querySelectorAll('.modal-backdrop').forEach(backdrop => {
    backdrop.addEventListener('click', (e) => {
      if (e.target === backdrop) closeModal(backdrop.id);
    });
  });

  document.querySelectorAll('[data-modal-close]').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.closest('.modal-backdrop').id;
      closeModal(id);
    });
  });

  // ESC key
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      document.querySelectorAll('.modal-backdrop.open').forEach(m => closeModal(m.id));
    }
  });
}

function openModal(id) {
  const modal = document.getElementById(id);
  if (modal) modal.classList.add('open');
}

function closeModal(id) {
  const modal = document.getElementById(id);
  if (modal) modal.classList.remove('open');
}

// Expose globally for inline onclick usage
window.openModal  = openModal;
window.closeModal = closeModal;

// ─── Alert auto-dismiss ───────────────────────────────────────────────────────
function initAlertDismiss() {
  setTimeout(() => {
    document.querySelectorAll('.alert').forEach(a => {
      a.style.transition = 'opacity 0.5s';
      a.style.opacity = '0';
      setTimeout(() => a.remove(), 500);
    });
  }, 4500);
}

// ─── Highlight active nav link ────────────────────────────────────────────────
function initActiveNav() {
  const path = window.location.pathname;
  document.querySelectorAll('.nav-item').forEach(link => {
    const href = link.getAttribute('href');
    if (href && path.startsWith(href) && href !== '/') {
      link.classList.add('active');
    }
  });
}

// ─── Live table search ────────────────────────────────────────────────────────
function initTableSearch() {
  const searchInputs = document.querySelectorAll('[data-table-search]');
  searchInputs.forEach(input => {
    const tableId = input.getAttribute('data-table-search');
    const table   = document.getElementById(tableId);
    if (!table) return;
    input.addEventListener('input', () => {
      const q = input.value.toLowerCase();
      table.querySelectorAll('tbody tr').forEach(row => {
        const text = row.textContent.toLowerCase();
        row.style.display = text.includes(q) ? '' : 'none';
      });
    });
  });
}

// ─── Highlight stats on hover ─────────────────────────────────────────────────
function highlightCurrentStat() {
  document.querySelectorAll('.stat-card').forEach(card => {
    card.addEventListener('mouseenter', () => {
      card.style.transform = 'translateY(-2px)';
      card.style.transition = 'transform 0.2s ease, box-shadow 0.2s ease';
    });
    card.addEventListener('mouseleave', () => {
      card.style.transform = '';
    });
  });
}

// ─── Confirm delete ───────────────────────────────────────────────────────────
function confirmAction(form, msg) {
  if (confirm(msg || 'Are you sure?')) form.submit();
}

// ─── Pre-fill edit modals ─────────────────────────────────────────────────────
function fillModal(modalId, dataMap) {
  const modal = document.getElementById(modalId);
  if (!modal) return;
  Object.entries(dataMap).forEach(([name, value]) => {
    const el = modal.querySelector(`[name="${name}"]`);
    if (!el) return;
    if (el.type === 'checkbox') {
      el.checked = !!value;
    } else if (el.tagName === 'SELECT') {
      el.value = value;
    } else {
      el.value = value ?? '';
    }
  });
}

// ─── Department checkbox helpers ──────────────────────────────────────────────
function fillDeptCheckboxes(modalId, depts) {
  const modal = document.getElementById(modalId);
  if (!modal) return;
  modal.querySelectorAll('input[name="allowed_departments"]').forEach(cb => {
    cb.checked = depts && depts.includes(cb.value);
  });
}

// ─── Copy to clipboard ────────────────────────────────────────────────────────
function copyText(text) {
  navigator.clipboard.writeText(text).then(() => {
    showToast('Copied to clipboard!');
  });
}

// ─── Mini toast ───────────────────────────────────────────────────────────────
function showToast(msg) {
  const t = document.createElement('div');
  t.textContent = msg;
  t.style.cssText = `
    position:fixed;bottom:24px;right:24px;background:#1E3A8A;color:#fff;
    padding:10px 18px;border-radius:8px;font-size:13.5px;font-weight:500;
    box-shadow:0 4px 16px rgba(0,0,0,0.15);z-index:9999;
    animation:fadeInUp .3s ease;
  `;
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 2800);
}

// ─── Format dates nicely ──────────────────────────────────────────────────────
function formatDate(dateStr) {
  if (!dateStr) return '—';
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
}
