import {
  Activity,
  ArrowDownRight,
  CalendarDays,
  Coffee,
  Cookie,
  Download,
  Drumstick,
  Dumbbell,
  Flame,
  GlassWater,
  History,
  Droplet,
  Droplets,
  Moon,
  Nut,
  Pencil,
  Pill,
  Plus,
  Salad,
  Save,
  Scale,
  Settings,
  Soup,
  Target,
  Trash2,
  Utensils,
  Wheat
} from "lucide-react";
import type { ComponentType } from "react";
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  calculateBmr,
  calculateMacroCalories,
  shouldWarnMacroCalories,
  type DayType,
  type EntryCreateInput,
  type MealSlot
} from "@diet/shared";
import { ApiError, api } from "./api";
import type { DayLog, Entry, Profile, Summary, Target as TargetType } from "./types";

type View = "today" | "history" | "settings";

const mealSlots: MealSlot[] = [
  "breakfast",
  "lunch",
  "dinner",
  "snack",
  "drink",
  "supplement",
  "other"
];

const mealMeta: Record<MealSlot, { icon: ComponentType<{ size?: number }>; tone: string }> = {
  breakfast: { icon: Coffee, tone: "amber" },
  lunch: { icon: Utensils, tone: "green" },
  dinner: { icon: Soup, tone: "plum" },
  snack: { icon: Cookie, tone: "amber" },
  drink: { icon: GlassWater, tone: "blue" },
  supplement: { icon: Pill, tone: "green" },
  other: { icon: Salad, tone: "green" }
};

const emptyEntry = (localDate: string): EntryCreateInput => ({
  local_date: localDate,
  logged_at: new Date().toISOString(),
  meal_slot: "lunch",
  name: "",
  calories_kcal: 0,
  carbs_g: 0,
  protein_g: 0,
  fat_g: 0,
  water_ml: 0,
  notes: null
});

export default function App() {
  const today = useMemo(() => localDate(new Date()), []);
  const [view, setView] = useState<View>("today");
  const [profile, setProfile] = useState<Profile | null>(null);
  const [targets, setTargets] = useState<TargetType[]>([]);
  const [day, setDay] = useState<DayLog | null>(null);
  const [summary, setSummary] = useState<Summary | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [entryDraft, setEntryDraft] = useState<EntryCreateInput>(emptyEntry(today));
  const [editingId, setEditingId] = useState<string | null>(null);
  const [entryOpen, setEntryOpen] = useState(false);
  const [weightDraft, setWeightDraft] = useState("");

  const historyRange = useMemo(
    () => ({
      start: addDays(today, -13),
      end: today
    }),
    [today]
  );

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [profileData, targetsData, dayData, summaryData] = await Promise.all([
        api.profile(),
        api.targets(),
        api.day(today),
        api.summary(historyRange.start, historyRange.end)
      ]);
      setProfile(profileData);
      setTargets(targetsData);
      setDay(dayData);
      setSummary(summaryData);
      setWeightDraft(String(dayData.body_weight?.weight_kg ?? profileData.current_weight_kg));
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [historyRange.end, historyRange.start, today]);

  useEffect(() => {
    void load();
  }, [load]);

  async function refreshDayAndSummary(nextDay?: DayLog) {
    if (nextDay != null) {
      setDay(nextDay);
    } else {
      setDay(await api.day(today));
    }
    setSummary(await api.summary(historyRange.start, historyRange.end));
  }

  async function changeDayType(dayType: DayType) {
    if (day == null || day.day_type === dayType) return;
    setSaving(true);
    try {
      const updated = await api.updateDay(day.local_date, { day_type: dayType });
      await refreshDayAndSummary(updated);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  async function saveEntry() {
    if (entryDraft.name.trim().length === 0) return;
    setSaving(true);
    setError(null);
    try {
      const payload = {
        ...entryDraft,
        name: entryDraft.name.trim(),
        notes: entryDraft.notes?.trim() || null
      };
      const result =
        editingId == null
          ? await api.createEntry(payload)
          : await api.updateEntry(editingId, {
              logged_at: payload.logged_at,
              meal_slot: payload.meal_slot,
              name: payload.name,
              calories_kcal: payload.calories_kcal,
              carbs_g: payload.carbs_g,
              protein_g: payload.protein_g,
              fat_g: payload.fat_g,
              water_ml: payload.water_ml,
              notes: payload.notes
            });
      await refreshDayAndSummary(result.day);
      setEntryDraft(emptyEntry(today));
      setEditingId(null);
      setEntryOpen(false);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  async function deleteEntry(id: string) {
    if (!window.confirm("Delete this entry?")) return;
    setSaving(true);
    try {
      const result = await api.deleteEntry(id);
      await refreshDayAndSummary(result.day);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  async function addWater(amount: number) {
    setSaving(true);
    try {
      const result = await api.createEntry({
        local_date: today,
        logged_at: new Date().toISOString(),
        meal_slot: "drink",
        name: `Water ${amount} ml`,
        calories_kcal: 0,
        carbs_g: 0,
        protein_g: 0,
        fat_g: 0,
        water_ml: amount,
        notes: null
      });
      await refreshDayAndSummary(result.day);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  async function saveWeight() {
    const weight = Number(weightDraft);
    if (!Number.isFinite(weight) || weight <= 0) return;
    setSaving(true);
    try {
      await api.addBodyWeight({
        local_date: today,
        measured_at: new Date().toISOString(),
        weight_kg: weight,
        notes: null
      });
      await refreshDayAndSummary();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  function startEdit(entry: Entry) {
    setEditingId(entry.id);
    setEntryDraft({
      local_date: today,
      logged_at: entry.logged_at,
      meal_slot: entry.meal_slot,
      name: entry.name,
      calories_kcal: entry.calories_kcal,
      carbs_g: entry.carbs_g,
      protein_g: entry.protein_g,
      fat_g: entry.fat_g,
      water_ml: entry.water_ml,
      notes: entry.notes
    });
    setEntryOpen(true);
  }

  if (loading) {
    return (
      <main className="app-shell">
        <Topbar today={today} view={view} onView={setView} />
        <div className="loading-grid" aria-busy="true">
          <div className="skeleton-panel" />
          <div className="skeleton-panel narrow" />
          <div className="skeleton-panel" />
        </div>
      </main>
    );
  }

  return (
    <main className="app-shell">
      <Topbar today={today} view={view} onView={setView} />

      {error != null && (
        <div className="error" role="alert">
          {error}
        </div>
      )}

      {view === "today" && day != null && (
        <TodayView
          day={day}
          saving={saving}
          entryDraft={entryDraft}
          entryOpen={entryOpen}
          editingId={editingId}
          weightDraft={weightDraft}
          onDayType={changeDayType}
          onAddWater={addWater}
          onEntryDraft={setEntryDraft}
          onEntryOpen={setEntryOpen}
          onSaveEntry={saveEntry}
          onEdit={startEdit}
          onDelete={deleteEntry}
          onWeightDraft={setWeightDraft}
          onSaveWeight={saveWeight}
        />
      )}

      {view === "history" && summary != null && <HistoryView summary={summary} />}

      {view === "settings" && profile != null && (
        <SettingsView
          profile={profile}
          targets={targets}
          onProfile={setProfile}
          onTargets={setTargets}
          onError={setError}
        />
      )}
    </main>
  );
}

function Topbar({
  today,
  view,
  onView
}: {
  today: string;
  view: View;
  onView: (view: View) => void;
}) {
  const tabs: { id: View; label: string; icon: ComponentType<{ size?: number }> }[] = [
    { id: "today", label: "Today", icon: Activity },
    { id: "history", label: "History", icon: History },
    { id: "settings", label: "Settings", icon: Settings }
  ];
  return (
    <header className="topbar">
      <div className="brand">
        <span className="brand-mark" aria-hidden="true">
          <Salad size={20} />
        </span>
        <div>
          <p className="eyebrow">
            <CalendarDays size={13} /> {formatLongDate(today)}
          </p>
          <h1>Diet Tracker</h1>
        </div>
      </div>
      <nav className="tabs" aria-label="Primary">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          return (
            <button
              key={tab.id}
              className={view === tab.id ? "active" : ""}
              onClick={() => onView(tab.id)}
              type="button"
              title={tab.label}
            >
              <Icon size={18} />
              <span>{tab.label}</span>
            </button>
          );
        })}
      </nav>
    </header>
  );
}

function TodayView(props: {
  day: DayLog;
  saving: boolean;
  entryDraft: EntryCreateInput;
  entryOpen: boolean;
  editingId: string | null;
  weightDraft: string;
  onDayType: (dayType: DayType) => void;
  onAddWater: (amount: number) => void;
  onEntryDraft: (draft: EntryCreateInput) => void;
  onEntryOpen: (open: boolean) => void;
  onSaveEntry: () => void;
  onEdit: (entry: Entry) => void;
  onDelete: (id: string) => void;
  onWeightDraft: (value: string) => void;
  onSaveWeight: () => void;
}) {
  const { day } = props;
  const macroCalories = calculateMacroCalories(props.entryDraft);
  const macroWarning = shouldWarnMacroCalories(
    props.entryDraft.calories_kcal,
    props.entryDraft
  );
  const remaining = day.calculated.remaining_intake_kcal;
  const eaten = day.totals.calories_kcal;
  const target = day.intake_target_kcal;
  const intakePct = Math.round((eaten / Math.max(target, 1)) * 100);
  const over = remaining < 0;

  return (
    <div className="tracker-grid">
      <section className="panel summary-panel">
        <div className="section-head">
          <div>
            <p className="eyebrow">Today</p>
            <h2>{capitalize(day.day_type)} day</h2>
          </div>
          <div className="segmented" aria-label="Day type">
            <button
              className={day.day_type === "training" ? "selected" : ""}
              onClick={() => props.onDayType("training")}
              type="button"
              data-testid="today.dayType.training"
            >
              <Dumbbell size={15} /> Training
            </button>
            <button
              className={day.day_type === "rest" ? "selected" : ""}
              onClick={() => props.onDayType("rest")}
              type="button"
              data-testid="today.dayType.rest"
            >
              <Moon size={15} /> Rest
            </button>
          </div>
        </div>

        <div className={`calorie-hero ${over ? "over" : ""}`}>
          <div className="calorie-hero-head">
            <div>
              <p className="eyebrow">{over ? "Over budget" : "Remaining"}</p>
              <strong className="calorie-value">
                {formatNumber(Math.abs(remaining))}
                <small>kcal</small>
              </strong>
            </div>
            <div className="calorie-sub">
              <Flame size={15} />
              <span>
                {formatNumber(eaten)} / {formatNumber(target)} kcal
              </span>
            </div>
          </div>
          <div className="hero-bar" aria-label="Calories progress">
            <span style={{ width: `${Math.min(100, intakePct)}%` }} />
          </div>
        </div>

        <div className="stat-row">
          <StatChip icon={Utensils} label="Eaten" value={formatNumber(eaten)} unit="kcal" />
          <StatChip
            icon={ArrowDownRight}
            label="Deficit"
            value={formatNumber(day.calculated.actual_deficit_kcal)}
            unit="kcal"
            tone="good"
          />
          <StatChip
            icon={Target}
            label="Burn"
            value={formatNumber(day.burn_kcal)}
            unit="kcal"
          />
        </div>

        <div className="macro-list">
          <MacroRow
            icon={Wheat}
            label="Carbs"
            value={day.totals.carbs_g}
            target={day.carbs_target_g}
            suffix="g"
            tone="amber"
          />
          <MacroRow
            icon={Drumstick}
            label="Protein"
            value={day.totals.protein_g}
            target={day.protein_target_g}
            suffix="g"
            tone="green"
          />
          <MacroRow
            icon={Nut}
            label="Fat"
            value={day.totals.fat_g}
            target={day.fat_target_g}
            suffix="g"
            tone="plum"
          />
          <MacroRow
            icon={Droplets}
            label="Water"
            value={day.totals.water_ml}
            target={day.water_target_ml}
            suffix="ml"
            tone="blue"
          />
        </div>

        <div className="quick-row">
          <button
            className="icon-button"
            onClick={() => props.onAddWater(250)}
            type="button"
            title="Add 250 ml water"
            disabled={props.saving}
          >
            <Droplet size={18} />
            <span>250 ml</span>
          </button>
          <button
            className="icon-button"
            onClick={() => props.onAddWater(500)}
            type="button"
            title="Add 500 ml water"
            disabled={props.saving}
          >
            <Droplets size={18} />
            <span>500 ml</span>
          </button>
          <button
            className="icon-button primary"
            onClick={() => props.onEntryOpen(!props.entryOpen)}
            type="button"
            data-testid="today.addEntry"
            title="Add entry"
          >
            <Plus size={18} />
            <span>Quick add</span>
          </button>
        </div>
      </section>

      <section className="panel side-panel">
        <div className="section-head">
          <div>
            <p className="eyebrow">
              <Scale size={13} /> Body weight
            </p>
            <h2>
              {day.body_weight?.weight_kg ?? "--"}
              <small className="unit-suffix">kg</small>
            </h2>
          </div>
        </div>
        <p className="muted small">
          {day.body_weight == null
            ? "No weight logged today."
            : `Logged ${formatTime(day.body_weight.measured_at)}`}
        </p>
        <div className="inline-form">
          <input
            aria-label="Body weight"
            inputMode="decimal"
            type="number"
            value={props.weightDraft}
            onChange={(event) => props.onWeightDraft(event.target.value)}
          />
          <button
            className="icon-button primary"
            type="button"
            onClick={props.onSaveWeight}
            title="Save body weight"
          >
            <Save size={18} />
            <span>Save</span>
          </button>
        </div>
      </section>

      {props.entryOpen && (
        <section className="panel form-panel">
          <div className="section-head">
            <div>
              <p className="eyebrow">{props.editingId == null ? "Add" : "Edit"}</p>
              <h2>Food entry</h2>
            </div>
            <button
              className="ghost"
              type="button"
              onClick={() => props.onEntryOpen(false)}
            >
              Cancel
            </button>
          </div>

          <div className="form-grid">
            <label>
              Time
              <input
                type="datetime-local"
                value={toDateTimeLocal(props.entryDraft.logged_at ?? "")}
                onChange={(event) =>
                  props.onEntryDraft({
                    ...props.entryDraft,
                    logged_at: new Date(event.target.value).toISOString()
                  })
                }
              />
            </label>
            <label>
              Meal
              <select
                value={props.entryDraft.meal_slot}
                onChange={(event) =>
                  props.onEntryDraft({
                    ...props.entryDraft,
                    meal_slot: event.target.value as MealSlot
                  })
                }
              >
                {mealSlots.map((slot) => (
                  <option key={slot} value={slot}>
                    {capitalize(slot)}
                  </option>
                ))}
              </select>
            </label>
            <label className="wide">
              Name
              <input
                value={props.entryDraft.name}
                onChange={(event) =>
                  props.onEntryDraft({ ...props.entryDraft, name: event.target.value })
                }
              />
            </label>
            <NumberField
              label="Calories"
              value={props.entryDraft.calories_kcal}
              testId="entry.calories"
              onChange={(calories_kcal) =>
                props.onEntryDraft({ ...props.entryDraft, calories_kcal })
              }
            />
            <NumberField
              label="Carbs"
              value={props.entryDraft.carbs_g}
              testId="entry.carbs"
              onChange={(carbs_g) => props.onEntryDraft({ ...props.entryDraft, carbs_g })}
            />
            <NumberField
              label="Protein"
              value={props.entryDraft.protein_g}
              testId="entry.protein"
              onChange={(protein_g) =>
                props.onEntryDraft({ ...props.entryDraft, protein_g })
              }
            />
            <NumberField
              label="Fat"
              value={props.entryDraft.fat_g}
              testId="entry.fat"
              onChange={(fat_g) => props.onEntryDraft({ ...props.entryDraft, fat_g })}
            />
            <NumberField
              label="Water"
              value={props.entryDraft.water_ml}
              testId="entry.water"
              onChange={(water_ml) =>
                props.onEntryDraft({ ...props.entryDraft, water_ml })
              }
            />
          </div>

          <div className="form-footer">
            <div className={macroWarning ? "macro-note warn" : "macro-note"}>
              <Flame size={15} />
              Macro estimate: {formatNumber(macroCalories)} kcal
            </div>
            <button
              className="icon-button primary"
              type="button"
              onClick={props.onSaveEntry}
              disabled={props.saving || props.entryDraft.name.trim().length === 0}
              data-testid="entry.save"
            >
              <Save size={18} />
              <span>Save entry</span>
            </button>
          </div>
        </section>
      )}

      <section className="panel entries-panel">
        <div className="section-head">
          <div>
            <p className="eyebrow">Entries</p>
            <h2>Logged today</h2>
          </div>
          <span className="count-pill">{day.entries.length}</span>
        </div>
        <div className="entry-list">
          {day.entries.length === 0 && (
            <div className="empty-state">
              <Utensils size={22} />
              <p>No entries yet</p>
              <span>Use Quick add to log your first meal.</span>
            </div>
          )}
          {day.entries.map((entry) => {
            const meta = mealMeta[entry.meal_slot];
            const Icon = meta.icon;
            return (
              <article className="entry-row" key={entry.id}>
                <span className={`meal-icon tone-${meta.tone}`} aria-hidden="true">
                  <Icon size={18} />
                </span>
                <div className="entry-main">
                  <strong>{entry.name}</strong>
                  <span>
                    {capitalize(entry.meal_slot)} · {formatTime(entry.logged_at)}
                  </span>
                </div>
                <div className="entry-numbers">
                  <span className="kcal">{formatNumber(entry.calories_kcal)} kcal</span>
                  <span>{formatNumber(entry.protein_g)} P</span>
                  <span>{formatNumber(entry.carbs_g)} C</span>
                  <span>{formatNumber(entry.water_ml)} ml</span>
                </div>
                <div className="entry-actions">
                  <button
                    className="icon-only"
                    type="button"
                    onClick={() => props.onEdit(entry)}
                    title="Edit entry"
                  >
                    <Pencil size={17} />
                  </button>
                  <button
                    className="icon-only danger"
                    type="button"
                    onClick={() => props.onDelete(entry.id)}
                    title="Delete entry"
                  >
                    <Trash2 size={17} />
                  </button>
                </div>
              </article>
            );
          })}
        </div>
      </section>
    </div>
  );
}

function HistoryView({ summary }: { summary: Summary }) {
  return (
    <div className="history-layout">
      <section className="panel">
        <div className="section-head">
          <div>
            <p className="eyebrow">
              {summary.start} – {summary.end}
            </p>
            <h2>Two-week summary</h2>
          </div>
          <div className="count-strip" data-testid="history.summary">
            <span className="tag training">{summary.counts.training} training</span>
            <span className="tag rest">{summary.counts.rest} rest</span>
            <span className="tag">{summary.counts.days} logged</span>
          </div>
        </div>
        <div className="stat-row four">
          <StatChip
            icon={Flame}
            label="Avg kcal"
            value={formatNumber(summary.averages.calories_kcal)}
          />
          <StatChip
            icon={Drumstick}
            label="Avg protein"
            value={formatNumber(summary.averages.protein_g)}
            unit="g"
          />
          <StatChip
            icon={Droplets}
            label="Avg water"
            value={formatNumber(summary.averages.water_ml)}
            unit="ml"
            tone="blue"
          />
          <StatChip
            icon={ArrowDownRight}
            label="Deficit"
            value={formatNumber(summary.estimated_deficit_kcal)}
            unit="kcal"
            tone="good"
          />
        </div>
      </section>
      <section className="panel">
        <div className="section-head">
          <div>
            <p className="eyebrow">Trend</p>
            <h2>Kcal and weight</h2>
          </div>
          <div className="legend">
            <span className="legend-item kcal">Kcal</span>
            <span className="legend-item weight">Weight</span>
          </div>
        </div>
        <TrendChart days={summary.days} />
      </section>
      <section className="panel">
        <div className="section-head">
          <div>
            <p className="eyebrow">Days</p>
            <h2>Recent logs</h2>
          </div>
        </div>
        <div className="day-table">
          <div className="day-row head">
            <span>Date</span>
            <span>Type</span>
            <span>Kcal</span>
            <span>Protein</span>
            <span>Water</span>
          </div>
          {summary.days.map((day) => (
            <div className="day-row" key={day.id}>
              <span className="strong">{formatShortDate(day.local_date)}</span>
              <span>
                <span className={`tag ${day.day_type}`}>{capitalize(day.day_type)}</span>
              </span>
              <span>{formatNumber(day.totals.calories_kcal)} kcal</span>
              <span>{formatNumber(day.totals.protein_g)} g</span>
              <span>{formatNumber(day.totals.water_ml)} ml</span>
            </div>
          ))}
          {summary.days.length === 0 && (
            <div className="empty-state">
              <CalendarDays size={22} />
              <p>No logged days yet</p>
              <span>Your daily logs will appear here.</span>
            </div>
          )}
        </div>
      </section>
    </div>
  );
}

function SettingsView(props: {
  profile: Profile;
  targets: TargetType[];
  onProfile: (profile: Profile) => void;
  onTargets: (targets: TargetType[]) => void;
  onError: (message: string | null) => void;
}) {
  const [profileDraft, setProfileDraft] = useState(props.profile);
  const bmr = calculateBmr(profileDraft);

  async function saveProfile() {
    try {
      const updated = await api.updateProfile({
        display_name: profileDraft.display_name,
        email: profileDraft.email,
        sex: profileDraft.sex,
        age: Number(profileDraft.age),
        height_cm: Number(profileDraft.height_cm),
        current_weight_kg: Number(profileDraft.current_weight_kg),
        timezone: profileDraft.timezone,
        activity_factor: Number(profileDraft.activity_factor),
        training_exercise_kcal: Number(profileDraft.training_exercise_kcal)
      });
      props.onProfile(updated);
      props.onError(null);
    } catch (err) {
      props.onError(errorMessage(err));
    }
  }

  async function saveTarget(dayType: DayType, target: TargetType) {
    try {
      const updated = await api.updateTarget(dayType, {
        burn_kcal: Number(target.burn_kcal),
        intake_kcal: Number(target.intake_kcal),
        deficit_kcal: Number(target.deficit_kcal),
        carbs_g: Number(target.carbs_g),
        protein_g: Number(target.protein_g),
        fat_g: Number(target.fat_g),
        water_ml: Number(target.water_ml)
      });
      props.onTargets(
        props.targets.map((item) => (item.day_type === dayType ? updated : item))
      );
      props.onError(null);
    } catch (err) {
      props.onError(errorMessage(err));
    }
  }

  function updateTarget(dayType: DayType, field: keyof TargetType, value: number) {
    props.onTargets(
      props.targets.map((target) =>
        target.day_type === dayType ? { ...target, [field]: value } : target
      )
    );
  }

  return (
    <div className="settings-layout">
      <section className="panel">
        <div className="section-head">
          <div>
            <p className="eyebrow">Profile</p>
            <h2>{Math.round(bmr)} kcal BMR</h2>
          </div>
          <button
            className="icon-button primary"
            type="button"
            onClick={saveProfile}
            data-testid="settings.profile"
          >
            <Save size={18} />
            <span>Save</span>
          </button>
        </div>
        <div className="field-group">
          <p className="group-label">Identity</p>
          <div className="form-grid">
            <TextSetting
              label="Name"
              value={profileDraft.display_name}
              onChange={(display_name) =>
                setProfileDraft({ ...profileDraft, display_name })
              }
            />
            <TextSetting
              label="Email"
              value={profileDraft.email}
              onChange={(email) => setProfileDraft({ ...profileDraft, email })}
            />
            <label>
              Sex
              <select
                value={profileDraft.sex}
                onChange={(event) =>
                  setProfileDraft({
                    ...profileDraft,
                    sex: event.target.value as "male" | "female"
                  })
                }
              >
                <option value="male">Male</option>
                <option value="female">Female</option>
              </select>
            </label>
            <TextSetting
              label="Timezone"
              value={profileDraft.timezone}
              onChange={(timezone) => setProfileDraft({ ...profileDraft, timezone })}
            />
          </div>
        </div>
        <div className="field-group">
          <p className="group-label">Body &amp; activity</p>
          <div className="form-grid">
            <NumericSetting
              label="Age"
              value={profileDraft.age}
              onChange={(age) => setProfileDraft({ ...profileDraft, age })}
            />
            <NumericSetting
              label="Height cm"
              value={profileDraft.height_cm}
              onChange={(height_cm) => setProfileDraft({ ...profileDraft, height_cm })}
            />
            <NumericSetting
              label="Weight kg"
              value={profileDraft.current_weight_kg}
              onChange={(current_weight_kg) =>
                setProfileDraft({ ...profileDraft, current_weight_kg })
              }
            />
            <NumericSetting
              label="Activity"
              value={profileDraft.activity_factor}
              step="0.05"
              onChange={(activity_factor) =>
                setProfileDraft({ ...profileDraft, activity_factor })
              }
            />
            <NumericSetting
              label="Exercise kcal"
              value={profileDraft.training_exercise_kcal}
              onChange={(training_exercise_kcal) =>
                setProfileDraft({ ...profileDraft, training_exercise_kcal })
              }
            />
          </div>
        </div>
      </section>

      <section className="panel">
        <div className="section-head">
          <div>
            <p className="eyebrow">Targets</p>
            <h2>Training and rest</h2>
          </div>
          <a className="icon-button" href="/api/v1/export.json" download>
            <Download size={18} />
            <span>Export</span>
          </a>
        </div>
        <div className="target-grid">
          {props.targets.map((target) => (
            <div className="target-row" key={target.day_type}>
              <div className="target-head">
                <span className={`tag ${target.day_type}`}>
                  {target.day_type === "training" ? (
                    <Dumbbell size={14} />
                  ) : (
                    <Moon size={14} />
                  )}
                  {capitalize(target.day_type)}
                </span>
                <button
                  className="icon-button primary"
                  type="button"
                  onClick={() => saveTarget(target.day_type, target)}
                >
                  <Save size={18} />
                  <span>Save</span>
                </button>
              </div>
              <div className="target-fields">
                <NumericSetting
                  label="Burn"
                  value={target.burn_kcal}
                  onChange={(value) => updateTarget(target.day_type, "burn_kcal", value)}
                />
                <NumericSetting
                  label="Intake"
                  value={target.intake_kcal}
                  onChange={(value) =>
                    updateTarget(target.day_type, "intake_kcal", value)
                  }
                />
                <NumericSetting
                  label="Deficit"
                  value={target.deficit_kcal}
                  onChange={(value) =>
                    updateTarget(target.day_type, "deficit_kcal", value)
                  }
                />
                <NumericSetting
                  label="Carbs"
                  value={target.carbs_g}
                  onChange={(value) => updateTarget(target.day_type, "carbs_g", value)}
                />
                <NumericSetting
                  label="Protein"
                  value={target.protein_g}
                  onChange={(value) => updateTarget(target.day_type, "protein_g", value)}
                />
                <NumericSetting
                  label="Fat"
                  value={target.fat_g}
                  onChange={(value) => updateTarget(target.day_type, "fat_g", value)}
                />
                <NumericSetting
                  label="Water"
                  value={target.water_ml}
                  onChange={(value) => updateTarget(target.day_type, "water_ml", value)}
                />
              </div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}

function StatChip({
  icon: Icon,
  label,
  value,
  unit,
  tone
}: {
  icon: ComponentType<{ size?: number }>;
  label: string;
  value: string;
  unit?: string;
  tone?: "good" | "danger" | "blue";
}) {
  return (
    <div className={`stat-chip ${tone ?? ""}`}>
      <span className="stat-icon" aria-hidden="true">
        <Icon size={16} />
      </span>
      <span className="stat-label">{label}</span>
      <strong>
        {value}
        {unit != null && <small>{unit}</small>}
      </strong>
    </div>
  );
}

function MacroRow({
  icon: Icon,
  label,
  value,
  target,
  suffix,
  tone
}: {
  icon: ComponentType<{ size?: number }>;
  label: string;
  value: number;
  target: number;
  suffix: string;
  tone: string;
}) {
  const percent = Math.round((value / Math.max(target, 1)) * 100);
  const over = percent > 100;
  return (
    <div className="macro-row">
      <span className={`macro-icon tone-${tone}`} aria-hidden="true">
        <Icon size={16} />
      </span>
      <div className="macro-body">
        <div className="macro-line">
          <span className="macro-label">{label}</span>
          <strong>
            {formatNumber(value)} / {formatNumber(target)} {suffix}
          </strong>
        </div>
        <div className={`bar tone-${tone} ${over ? "over" : ""}`} aria-label={`${label} progress`}>
          <span style={{ width: `${Math.min(100, percent)}%` }} />
        </div>
      </div>
      <span className={`pct ${over ? "over" : ""}`}>{percent}%</span>
    </div>
  );
}

function NumberField({
  label,
  value,
  testId,
  onChange
}: {
  label: string;
  value: number;
  testId: string;
  onChange: (value: number) => void;
}) {
  return (
    <label>
      {label}
      <input
        data-testid={testId}
        inputMode="decimal"
        min="0"
        type="number"
        value={value}
        onChange={(event) => onChange(numberValue(event.target.value))}
      />
    </label>
  );
}

function NumericSetting({
  label,
  value,
  step,
  onChange
}: {
  label: string;
  value: number;
  step?: string;
  onChange: (value: number) => void;
}) {
  return (
    <label>
      {label}
      <input
        type="number"
        step={step ?? "1"}
        value={value}
        onChange={(event) => onChange(numberValue(event.target.value))}
      />
    </label>
  );
}

function TextSetting({
  label,
  value,
  onChange
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <label>
      {label}
      <input value={value} onChange={(event) => onChange(event.target.value)} />
    </label>
  );
}

function TrendChart({ days }: { days: DayLog[] }) {
  const sorted = [...days].reverse();
  const values = sorted.map((day) => day.totals.calories_kcal);
  const max = Math.max(...values, 1);
  const coords = values.map((value, index) => {
    const x = sorted.length <= 1 ? 280 : 10 + (index / (sorted.length - 1)) * 280;
    const y = 118 - (value / max) * 96;
    return { x, y };
  });
  const points = coords.map((c) => `${c.x},${c.y}`).join(" ");
  const first = coords[0];
  const last = coords[coords.length - 1];
  const area =
    first != null && last != null ? `${first.x},122 ${points} ${last.x},122` : "";
  const weightValues = sorted
    .map((day) => day.body_weight?.weight_kg)
    .filter((value): value is number => value != null);
  const wMin = Math.min(...weightValues, Infinity);
  const wMax = Math.max(...weightValues, -Infinity);
  const wRange = wMax - wMin || 1;
  const weightPoints = sorted
    .map((day, index) => ({ day, index }))
    .filter(({ day }) => day.body_weight != null)
    .map(({ day, index }) => {
      const x = sorted.length <= 1 ? 280 : 10 + (index / (sorted.length - 1)) * 280;
      const y = 116 - (((day.body_weight?.weight_kg ?? 0) - wMin) / wRange) * 70;
      return `${x},${y}`;
    })
    .join(" ");

  return (
    <svg className="trend-chart" viewBox="0 0 300 132" role="img" preserveAspectRatio="none">
      <title>Kcal and weight trend</title>
      <defs>
        <linearGradient id="kcalFill" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stopColor="#2f7d57" stopOpacity="0.28" />
          <stop offset="100%" stopColor="#2f7d57" stopOpacity="0" />
        </linearGradient>
      </defs>
      <line className="axis" x1="0" x2="300" y1="122" y2="122" />
      {area.length > 0 && <polygon className="area" points={area} fill="url(#kcalFill)" />}
      {points.length > 0 && <polyline points={points} />}
      {weightPoints.length > 0 && <polyline className="weight" points={weightPoints} />}
    </svg>
  );
}

function errorMessage(err: unknown): string {
  if (err instanceof ApiError) {
    return `API ${err.status}: ${JSON.stringify(err.details)}`;
  }
  if (err instanceof Error) return err.message;
  return "Unexpected error";
}

function localDate(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function addDays(dateText: string, offset: number): string {
  const date = new Date(`${dateText}T00:00:00`);
  date.setDate(date.getDate() + offset);
  return localDate(date);
}

function toDateTimeLocal(iso: string): string {
  if (iso.length === 0) return "";
  const date = new Date(iso);
  const offsetMs = date.getTimezoneOffset() * 60_000;
  return new Date(date.getTime() - offsetMs).toISOString().slice(0, 16);
}

function formatTime(iso: string): string {
  return new Intl.DateTimeFormat(undefined, {
    hour: "numeric",
    minute: "2-digit"
  }).format(new Date(iso));
}

function formatLongDate(dateText: string): string {
  return new Intl.DateTimeFormat(undefined, {
    weekday: "long",
    month: "long",
    day: "numeric"
  }).format(new Date(`${dateText}T00:00:00`));
}

function formatShortDate(dateText: string): string {
  return new Intl.DateTimeFormat(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric"
  }).format(new Date(`${dateText}T00:00:00`));
}

function formatNumber(value: number): string {
  return new Intl.NumberFormat(undefined, {
    maximumFractionDigits: value % 1 === 0 ? 0 : 1
  }).format(value);
}

function numberValue(value: string): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function capitalize(value: string): string {
  return value.charAt(0).toUpperCase() + value.slice(1);
}
