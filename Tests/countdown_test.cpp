#include "Countdown.hpp"

#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>

namespace {

int g_failed = 0;

void check(bool condition, const char* expression, const char* file, int line) {
    if (!condition) {
        std::fprintf(stderr, "FAIL %s:%d: %s\n", file, line, expression);
        ++g_failed;
    }
}

#define CHECK(condition) check((condition), #condition, __FILE__, __LINE__)

}  // namespace

int main() {
    using namespace countcount;

    CHECK(isValidDate(CivilDate {1970, 1, 1}));
    CHECK(isValidDate(CivilDate {2024, 2, 29}));
    CHECK(isValidDate(CivilDate {2000, 2, 29}));
    CHECK(!isValidDate(CivilDate {2023, 2, 29}));
    CHECK(!isValidDate(CivilDate {1900, 2, 29}));
    CHECK(!isValidDate(CivilDate {2024, 4, 31}));
    CHECK(!isValidDate(CivilDate {0, 1, 1}));
    CHECK(!isValidDate(CivilDate {2024, 13, 1}));
    CHECK(isValidDate(CivilDate {9999, 12, 31}));

    CHECK(daysBetween(CivilDate {1970, 1, 1}, CivilDate {1970, 1, 1}) == 0);
    CHECK(daysBetween(CivilDate {1970, 1, 1}, CivilDate {1970, 1, 2}) == 1);
    CHECK(daysBetween(CivilDate {1970, 1, 2}, CivilDate {1970, 1, 1}) == -1);
    CHECK(daysBetween(CivilDate {1969, 12, 31}, CivilDate {1970, 1, 1}) == 1);
    CHECK(daysBetween(CivilDate {2024, 2, 28}, CivilDate {2024, 3, 1}) == 2);
    CHECK(daysBetween(CivilDate {2023, 2, 28}, CivilDate {2023, 3, 1}) == 1);
    CHECK(daysBetween(CivilDate {2000, 2, 28}, CivilDate {2000, 3, 1}) == 2);
    CHECK(daysBetween(CivilDate {1900, 2, 28}, CivilDate {1900, 3, 1}) == 1);
    CHECK(daysBetween(CivilDate {2024, 12, 31}, CivilDate {2025, 1, 1}) == 1);
    CHECK(daysBetween(CivilDate {2023, 2, 29}, CivilDate {2023, 3, 1}) == 0);

    const CivilDate epoch {1970, 1, 1};
    auto weekdayName = [](CivilDate date) {
        return present(Event {"", date}, date).dateLine;
    };
    CHECK(weekdayName(epoch).find("Thursday") != std::string::npos);
    CHECK(weekdayName(CivilDate {2000, 1, 1}).find("Saturday") != std::string::npos);
    CHECK(weekdayName(CivilDate {2024, 1, 1}).find("Monday") != std::string::npos);
    CHECK(weekdayName(CivilDate {2024, 2, 29}).find("Thursday") != std::string::npos);
    CHECK(present(Event {"", CivilDate {2026, 2, 7}}, CivilDate {2026, 2, 7}).dateLine ==
          "Saturday, February 7, 2026");

    const CivilDate today {2026, 11, 10};
    const Presentation empty = present(std::nullopt, today);
    CHECK(!empty.configured);
    CHECK(empty.menuLabel == "Set date");
    CHECK(empty.headline == "Not set");

    Event spring;
    spring.title = "  Launch  ";
    spring.date = CivilDate {2027, 2, 6};
    const Presentation future = present(spring, today);
    CHECK(future.configured);
    CHECK(future.dayDelta == 88);
    CHECK(future.headline == "88");
    CHECK(future.unit == "days");
    CHECK(future.kicker == "Until Launch");
    CHECK(future.menuLabel == "Launch 88 days");
    CHECK(future.dateLine == "Saturday, February 6, 2027");
    MenuStyle hiddenTitle;
    hiddenTitle.includeTitle = false;
    CHECK(present(spring, today, hiddenTitle).menuLabel == "88 days");

    Event todayEvent;
    todayEvent.title = "Ship";
    todayEvent.date = today;
    const Presentation sameDay = present(todayEvent, today);
    CHECK(sameDay.dayDelta == 0);
    CHECK(sameDay.headline == "Today");
    CHECK(sameDay.unit.empty());
    CHECK(sameDay.menuLabel == "Ship today");
    CHECK(sameDay.kicker == "Ship is today");
    CHECK(sameDay.dateLine == "Tuesday, November 10, 2026");

    Event past;
    past.date = CivilDate {2026, 11, 7};
    const Presentation ago = present(past, today);
    CHECK(ago.dayDelta == -3);
    CHECK(ago.headline == "3");
    CHECK(ago.unit == "days ago");
    CHECK(ago.kicker == "Days since");
    CHECK(ago.menuLabel == "3 days ago");

    Event yesterday;
    yesterday.title = "Ship";
    yesterday.date = CivilDate {2026, 11, 9};
    const Presentation oneAgo = present(yesterday, today);
    CHECK(oneAgo.dayDelta == -1);
    CHECK(oneAgo.unit == "day ago");
    CHECK(oneAgo.menuLabel == "Ship 1 day ago");

    Event far;
    far.title = "abcdefghijklmnopqrstuvwxyz";
    far.date = CivilDate {2030, 1, 1};
    const Presentation longTitle = present(far, today);
    CHECK(longTitle.menuLabel.find("days") != std::string::npos);
    CHECK(longTitle.headline == "1,148");
    CHECK(longTitle.kicker.find("abcdefghijklmnopqrstuvwxyz") != std::string::npos);

    Event untitled;
    untitled.date = CivilDate {2026, 11, 11};
    CHECK(present(untitled, today).menuLabel == "1 day");
    CHECK(present(untitled, today).unit == "day");
    CHECK(present(untitled, today).kicker == "Days left");

    const auto directory = std::filesystem::temp_directory_path() / "countcount-test";
    std::filesystem::remove_all(directory);
    std::filesystem::create_directories(directory);
    Store store(directory / "event.json");
    CHECK(!store.load().has_value());

    Event saved;
    saved.title = "春节\"\\2027";
    saved.date = CivilDate {2027, 2, 6};
    CHECK(store.save(saved));
    const auto loaded = store.load();
    CHECK(loaded.has_value());
    CHECK(loaded->title == "春节\"\\2027");
    CHECK(loaded->date == saved.date);

    Event emoji;
    emoji.title = "派对";
    emoji.date = CivilDate {2028, 1, 1};
    CHECK(store.save(emoji));
    std::string raw = std::string("{\n  \"day\": 1, \"month\": 1,\n  \"year\": 2028, \"title\": \"\\uD83C\\uDF89\\u6625\\u8282\"\n}\n");
    {
        std::ofstream output(store.path(), std::ios::binary | std::ios::trunc);
        output << raw;
    }
    const auto decoded = store.load();
    CHECK(decoded.has_value());
    CHECK(decoded->title == "🎉春节");
    CHECK(decoded->date == (CivilDate {2028, 1, 1}));

    {
        std::ofstream output(store.path(), std::ios::binary | std::ios::trunc);
        output << "{\"title\":\"x\",\"year\":2023,\"month\":2,\"day\":29}";
    }
    CHECK(!store.load().has_value());

    Event invalid;
    invalid.date = CivilDate {2023, 2, 29};
    CHECK(!store.save(invalid));

    Event padded;
    padded.title = "  生日  ";
    padded.date = CivilDate {2026, 12, 1};
    CHECK(store.save(padded));
    CHECK(store.load()->title == "生日");

    std::string longName(50, 'a');
    Event clipped;
    clipped.title = longName;
    clipped.date = CivilDate {2026, 12, 2};
    CHECK(store.save(clipped));
    CHECK(store.load()->title.size() == 40);

    CHECK(store.clear());
    CHECK(!store.load().has_value());
    CHECK(store.clear());

    CHECK(isValidDate(todayLocal()));

    std::filesystem::remove_all(directory);
    if (g_failed != 0) {
        std::fprintf(stderr, "%d checks failed\n", g_failed);
        return 1;
    }
    std::puts("ok");
    return 0;
}
