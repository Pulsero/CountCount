#pragma once

#include <filesystem>
#include <optional>
#include <string>
#include <vector>

namespace countcount {

struct CivilDate {
    int year = 0;
    int month = 0;
    int day = 0;

    friend bool operator==(const CivilDate& a, const CivilDate& b) {
        return a.year == b.year && a.month == b.month && a.day == b.day;
    }
};

struct Event {
    std::string title;
    CivilDate date;
};

struct Presentation {
    std::string menuLabel;
    std::string tooltip;
    std::string kicker;
    std::string headline;
    std::string unit;
    std::string dateLine;
    int dayDelta = 0;
    bool configured = false;
};

struct MenuStyle {
    bool includeTitle = true;
};

bool isValidDate(CivilDate date);
int daysBetween(CivilDate from, CivilDate to);
CivilDate todayLocal();
Presentation present(const std::optional<Event>& event, CivilDate today, MenuStyle style = {});

class Store {
public:
    explicit Store(std::filesystem::path file);

    std::optional<Event> load() const;
    bool save(const Event& event) const;
    bool clear() const;

    const std::filesystem::path& path() const { return file_; }

private:
    std::filesystem::path file_;
};

struct Goal {
    std::string id;
    std::string title;
    bool done = false;

    friend bool operator==(const Goal& a, const Goal& b) {
        return a.id == b.id && a.title == b.title && a.done == b.done;
    }
};

std::string makeGoalId();

class GoalStore {
public:
    explicit GoalStore(std::filesystem::path file);

    // An empty vector when the file is absent. nullopt when the file cannot be read.
    std::optional<std::vector<Goal>> load() const;
    bool save(const std::vector<Goal>& goals) const;

    const std::filesystem::path& path() const { return file_; }

private:
    std::filesystem::path file_;
};

}  // namespace countcount
