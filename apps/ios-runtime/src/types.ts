export type TempoRoute = 'inbox' | 'today' | 'focus' | 'rss' | 'settings';

export type TaskStatus = 'open' | 'completed' | 'cancelled';
export type TaskPriority = 'high' | 'medium' | 'low';

export type TempoTask = {
  id: string;
  title: string;
  notes: string;
  status: TaskStatus;
  priority?: TaskPriority | null;
  startAt?: string | null;
  deadlineAt?: string | null;
  completedAt?: string | null;
  createdAt: string;
  updatedAt: string;
};

export type FocusSession = {
  id: string;
  startedAt: string;
  endedAt: string;
  durationSeconds: number;
  completed: boolean;
};

export type PomodoroState = {
  mode: 'focus' | 'shortBreak' | 'longBreak';
  status: 'idle' | 'running' | 'paused';
  remainingSeconds: number;
  completedFocusSessions: number;
  focusMinutes: number;
  shortBreakMinutes: number;
  longBreakMinutes: number;
  longBreakEvery: number;
  dailyFocusGoal: number;
  timerDirection: 'countdown' | 'countUp';
  focusHistory: FocusSession[];
};

export type RSSSubscription = {
  id: string;
  title: string;
  feedURL: string;
  siteURL?: string | null;
  folderID?: string | null;
  iconURL?: string | null;
  lastError?: string | null;
};

export type RSSFolder = { id: string; title: string };

export type RSSArticle = {
  id: string;
  feedID: string;
  feedTitle: string;
  title: string;
  summary: string;
  link: string;
  author?: string | null;
  publishedAt?: string | null;
  fetchedAt: string;
  isRead: boolean;
  isStarred: boolean;
  readingProgress: number;
  content?: string | null;
};

export type TempoSnapshot = {
  route: TempoRoute;
  locale: string;
  colorScheme: 'light' | 'dark';
  revision: number;
  tasks: TempoTask[];
  pomodoro?: PomodoroState;
  displayedRemainingSeconds: number;
  sync?: {
    phase: string;
    revision: number;
    pendingChangeCount: number;
    lastAutomaticSync: string;
    configured: boolean;
    autoSync: boolean;
    serverURL: string;
    deviceName: string;
    hasToken: boolean;
  };
  ai?: {
    mode: 'selfHosted' | 'openAI' | 'deepSeek' | 'compatible';
    baseURL: string;
    model: string;
    summaryPrompt: string;
    configured: boolean;
    hasAPIKey: boolean;
  };
  rss?: {
    subscriptions: RSSSubscription[];
    folders: RSSFolder[];
    articles: RSSArticle[];
    unreadCount: number;
    phase: string;
  };
  ambient?: {
    quote?: { text: string; source: string; updatedAt: string };
    weather?: { cityName: string; temperature: string; text: string; icon: string };
  };
  preferences?: {
    haptics: boolean;
    completionSound: boolean;
    weekStartsMonday: boolean;
    showFestivals: boolean;
    showTaskIndicators: boolean;
    moduleOrder: string;
  };
  app?: {
    version: string;
    build: string;
    update: UpdateState;
  };
};

export type UpdateState = {
  state: 'idle' | 'checking' | 'current' | 'available' | 'failed';
  version?: string;
  notes?: string;
  message?: string;
  downloadURL?: string;
};

export type TempoCommand = { type: 'search' | 'options' | 'statistics' };
