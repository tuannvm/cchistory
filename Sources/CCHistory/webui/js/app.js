/**
 * CCHistory Web UI
 * Displays Claude Code sessions with polling and SSE updates
 */

class CCHistoryApp {
  constructor() {
    this.sessions = [];
    this.searchQuery = '';
    this.projectFilter = '';
    this.dateFilter = 'all';
    this.activeSessionId = null;
    this.messages = [];
    this.pollInterval = 5000; // 5 seconds
    this.pollTimer = null;
    this.eventSource = null;

    this.init();
  }

  init() {
    // Cache DOM elements
    this.elements = {
      searchInput: document.getElementById('searchInput'),
      clearSearch: document.getElementById('clearSearch'),
      projectFilter: document.getElementById('projectFilter'),
      dateFilter: document.getElementById('dateFilter'),
      sessionsList: document.getElementById('sessionsList'),
      loadingIndicator: document.getElementById('loadingIndicator'),
      noSessions: document.getElementById('noSessions'),
      noResults: document.getElementById('noResults'),
      errorState: document.getElementById('errorState'),
      retryButton: document.getElementById('retryButton'),
      connectionStatus: document.getElementById('connectionStatus'),
      lastUpdated: document.getElementById('lastUpdated'),
      messagesPanel: document.getElementById('messagesPanel'),
      messagesTitle: document.getElementById('messagesTitle'),
      messagesList: document.getElementById('messagesList'),
      messagesEmpty: document.getElementById('messagesEmpty'),
      backButton: document.getElementById('backButton')
    };

    // Setup event listeners
    this.setupEventListeners();

    // Load initial sessions
    this.loadSessions();

    // Start SSE updates
    this.startEventStream();

    // Start polling for updates
    this.startPolling();
  }

  setupEventListeners() {
    // Search input
    this.elements.searchInput.addEventListener('input', (e) => {
      this.searchQuery = e.target.value.trim();
      this.updateUI();
      this.elements.clearSearch.classList.toggle('hidden', !this.searchQuery);
      this.loadSessions();
    });

    // Clear search
    this.elements.clearSearch.addEventListener('click', () => {
      this.elements.searchInput.value = '';
      this.searchQuery = '';
      this.updateUI();
      this.elements.clearSearch.classList.add('hidden');
      this.loadSessions();
    });

    // Project filter
    this.elements.projectFilter.addEventListener('input', (e) => {
      this.projectFilter = e.target.value.trim();
      this.loadSessions();
    });

    // Date filter
    this.elements.dateFilter.addEventListener('change', (e) => {
      this.dateFilter = e.target.value;
      this.loadSessions();
    });

    // Retry button
    this.elements.retryButton.addEventListener('click', () => {
      this.elements.errorState.classList.add('hidden');
      this.loadSessions();
    });

    // Mobile back button
    this.elements.backButton.addEventListener('click', () => {
      this.clearActiveSession();
      this.updateUI();
    });

    // Handle visibility change - reload when tab becomes visible
    document.addEventListener('visibilitychange', () => {
      if (!document.hidden) {
        this.loadSessions();
        this.startEventStream();
        this.startPolling();
      } else {
        this.stopEventStream();
        this.stopPolling();
      }
    });
  }

  async loadSessions() {
    try {
      const params = this.buildSessionQueryParams();
      const response = await fetch(`/api/sessions${params ? `?${params}` : ''}`);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      this.sessions = await response.json();
      this.elements.errorState.classList.add('hidden');
      this.updateConnectionStatus(true);
      if (this.activeSessionId && !this.sessions.some((session) => session.id === this.activeSessionId)) {
        this.clearActiveSession();
      }
      this.updateUI();
    } catch (error) {
      console.error('Failed to load sessions:', error);
      this.updateConnectionStatus(false);
      this.showError();
    }
  }

  startPolling() {
    // Clear any existing timer
    this.stopPolling();

    // Poll every 5 seconds
    this.pollTimer = setInterval(() => {
      this.loadSessions();
    }, this.pollInterval);
  }

  buildSessionQueryParams() {
    const params = new URLSearchParams();

    if (this.searchQuery) {
      params.set('q', this.searchQuery);
    }

    if (this.projectFilter) {
      params.set('project', this.projectFilter);
    }

    const nowSeconds = Math.floor(Date.now() / 1000);
    if (this.dateFilter === 'hour') {
      params.set('since', String(nowSeconds - 3600));
    } else if (this.dateFilter === 'day') {
      params.set('since', String(nowSeconds - 86400));
    } else if (this.dateFilter === 'week') {
      params.set('since', String(nowSeconds - 604800));
    }

    return params.toString();
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer);
      this.pollTimer = null;
    }
  }

  startEventStream() {
    this.stopEventStream();
    try {
      this.eventSource = new EventSource('/api/stream');
      this.eventSource.addEventListener('sessions', () => {
        this.loadSessions();
        if (this.activeSessionId) {
          this.loadMessages(this.activeSessionId);
        }
      });
      this.eventSource.onopen = () => {
        this.updateConnectionStatus(true);
      };
      this.eventSource.onerror = () => {
        this.updateConnectionStatus(false);
      };
    } catch (error) {
      console.error('Failed to start event stream:', error);
    }
  }

  stopEventStream() {
    if (this.eventSource) {
      this.eventSource.close();
      this.eventSource = null;
    }
  }

  updateUI() {
    const filteredSessions = this.filterSessions();

    // Hide loading
    this.elements.loadingIndicator.classList.add('hidden');

    // Show appropriate state
    if (filteredSessions.length === 0) {
      this.elements.sessionsList.classList.add('hidden');
      if (this.sessions.length === 0) {
        this.elements.noSessions.classList.remove('hidden');
        this.elements.noResults.classList.add('hidden');
      } else {
        this.elements.noSessions.classList.add('hidden');
        this.elements.noResults.classList.remove('hidden');
      }
    } else {
      this.elements.noSessions.classList.add('hidden');
      this.elements.noResults.classList.add('hidden');
      this.elements.sessionsList.classList.remove('hidden');

      // Render sessions
      this.elements.sessionsList.replaceChildren(...filteredSessions.map(session => this.buildSessionCard(session)));
    }

    // Update last updated time
    this.elements.lastUpdated.textContent = `Updated ${new Date().toLocaleTimeString()}`;
  }

  filterSessions() {
    if (!this.searchQuery) {
      return this.sessions;
    }

    const query = this.searchQuery.toLowerCase();
    return this.sessions.filter(session => {
      return session.displayName.toLowerCase().includes(query) ||
             session.repoName.toLowerCase().includes(query) ||
             (session.gitBranch && session.gitBranch.toLowerCase().includes(query)) ||
             (session.projectPath && session.projectPath.toLowerCase().includes(query));
    });
  }

  buildSessionCard(session) {
    const card = document.createElement('div');
    card.className = 'session-card';
    card.dataset.sessionId = session.id;

    const header = document.createElement('div');
    header.className = 'session-header';

    const name = document.createElement('div');
    name.className = 'session-name';
    name.textContent = session.cleanedDisplayName || session.displayName;

    const time = document.createElement('div');
    time.className = 'session-time';
    time.textContent = session.formattedRelativeDate;

    header.appendChild(name);
    header.appendChild(time);

    const meta = document.createElement('div');
    meta.className = 'session-meta';

    const repo = document.createElement('span');
    repo.textContent = session.repoName;

    const messageCount = document.createElement('span');
    messageCount.textContent = `${session.messageCount} message${session.messageCount !== 1 ? 's' : ''}`;

    const project = document.createElement('span');
    project.className = 'project-path';
    project.textContent = session.projectPath;

    meta.appendChild(repo);
    meta.appendChild(messageCount);
    meta.appendChild(project);

    if (session.gitBranch) {
      const branch = document.createElement('span');
      branch.textContent = session.gitBranch;
      meta.appendChild(branch);
    }

    card.appendChild(header);
    card.appendChild(meta);
    card.addEventListener('click', () => {
      this.handleSessionClick(session.id, session.displayName);
    });

    if (this.activeSessionId === session.id) {
      card.classList.add('active');
    }

    return card;
  }

  handleSessionClick(sessionId, displayName) {
    this.activeSessionId = sessionId;
    this.elements.messagesPanel.classList.remove('hidden');
    this.elements.messagesPanel.classList.add('active'); // For mobile: show messages panel
    this.elements.messagesTitle.textContent = displayName;

    // On mobile, hide the sessions list when viewing messages
    const sessionsContainer = document.querySelector('.sessions');
    if (sessionsContainer && window.innerWidth <= 900) {
      sessionsContainer.classList.add('hidden-on-mobile');
      // Show back button on mobile
      this.elements.backButton.style.display = 'inline-block';
    }

    this.loadMessages(sessionId);
    this.updateUI();
  }

  clearActiveSession() {
    this.activeSessionId = null;
    this.messages = [];
    this.elements.messagesPanel.classList.add('hidden');
    this.elements.messagesPanel.classList.remove('active'); // For mobile: hide messages panel

    // On mobile, show the sessions list again
    const sessionsContainer = document.querySelector('.sessions');
    if (sessionsContainer) {
      sessionsContainer.classList.remove('hidden-on-mobile');
      // Hide back button when returning to sessions
      this.elements.backButton.style.display = 'none';
    }
  }

  async loadMessages(sessionId) {
    try {
      const response = await fetch(`/api/sessions/${encodeURIComponent(sessionId)}/messages`);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      this.messages = await response.json();
      this.renderMessages();
    } catch (error) {
      console.error('Failed to load messages:', error);
      this.messages = [];
      this.renderMessages();
    }
  }

  renderMessages() {
    this.elements.messagesList.replaceChildren();
    if (!this.messages.length) {
      this.elements.messagesEmpty.classList.remove('hidden');
      return;
    }

    this.elements.messagesEmpty.classList.add('hidden');
    const items = this.messages.map((message) => {
      const row = document.createElement('div');
      row.className = `message-row ${message.role === 'user' ? 'from-user' : 'from-assistant'}`;

      const role = document.createElement('div');
      role.className = 'message-role';
      role.textContent = message.role === 'user' ? 'User' : 'Assistant';

      const content = document.createElement('div');
      content.className = 'message-content';
      content.textContent = message.content;

      row.appendChild(role);
      row.appendChild(content);
      return row;
    });

    this.elements.messagesList.replaceChildren(...items);
  }

  showToast(message) {
    // Create toast if it doesn't exist
    let toast = document.querySelector('.toast');
    if (!toast) {
      toast = document.createElement('div');
      toast.className = 'toast';
      document.body.appendChild(toast);
    }

    toast.textContent = message;
    toast.classList.add('visible');

    // Hide after 2 seconds
    setTimeout(() => {
      toast.classList.remove('visible');
    }, 2000);
  }

  updateConnectionStatus(connected) {
    this.elements.connectionStatus.classList.toggle('connected', connected);
    this.elements.connectionStatus.classList.toggle('disconnected', !connected);
    this.elements.connectionStatus.title = connected ? 'Connected' : 'Disconnected';
  }

  showError() {
    this.elements.loadingIndicator.classList.add('hidden');
    this.elements.sessionsList.classList.add('hidden');
    this.elements.noSessions.classList.add('hidden');
    this.elements.noResults.classList.add('hidden');
    this.elements.errorState.classList.remove('hidden');
  }

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
}

// Initialize app when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => new CCHistoryApp());
} else {
  new CCHistoryApp();
}
