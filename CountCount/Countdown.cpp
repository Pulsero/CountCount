#include "Countdown.hpp"

#include <cctype>
#include <ctime>
#include <fstream>
#include <random>
#include <system_error>
#include <unordered_set>
#include <utility>

namespace countcount {
namespace {

bool isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
}

// Gregorian civil date to days since 1970-01-01 (Howard Hinnant).
int daysFromCivil(int year, int month, int day) {
    year -= month <= 2;
    const int era = (year >= 0 ? year : year - 399) / 400;
    const unsigned yoe = static_cast<unsigned>(year - era * 400);
    const unsigned m = static_cast<unsigned>(month);
    const unsigned d = static_cast<unsigned>(day);
    const unsigned doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1;
    const unsigned doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return era * 146097 + static_cast<int>(doe) - 719468;
}

int weekdaySunday0(CivilDate date) {
    int days = daysFromCivil(date.year, date.month, date.day);
    int mod = days % 7;
    if (mod < 0) {
        mod += 7;
    }
    return (mod + 4) % 7;
}

bool isAsciiOrIdeographicSpace(const std::string& text, size_t index, size_t& length) {
    if (index >= text.size()) {
        return false;
    }
    const unsigned char c = static_cast<unsigned char>(text[index]);
    if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f') {
        length = 1;
        return true;
    }
    if (c == 0xE3 && index + 2 < text.size() &&
        static_cast<unsigned char>(text[index + 1]) == 0x80 &&
        static_cast<unsigned char>(text[index + 2]) == 0x80) {
        length = 3;
        return true;
    }
    return false;
}

std::string trim(const std::string& text) {
    size_t begin = 0;
    size_t mark = 0;
    while (isAsciiOrIdeographicSpace(text, begin, mark)) {
        begin += mark;
    }
    size_t end = text.size();
    while (end > begin) {
        size_t start = end - 1;
        while (start > begin && (static_cast<unsigned char>(text[start]) & 0xC0) == 0x80) {
            --start;
        }
        size_t spaceLength = 0;
        if (!isAsciiOrIdeographicSpace(text, start, spaceLength) || start + spaceLength != end) {
            break;
        }
        end = start;
    }
    return text.substr(begin, end - begin);
}

size_t utf8Length(unsigned char c) {
    if ((c & 0x80) == 0) {
        return 1;
    }
    if ((c & 0xE0) == 0xC0) {
        return 2;
    }
    if ((c & 0xF0) == 0xE0) {
        return 3;
    }
    if ((c & 0xF8) == 0xF0) {
        return 4;
    }
    return 0;
}

int codePointCount(const std::string& text) {
    int count = 0;
    for (size_t i = 0; i < text.size();) {
        const size_t len = utf8Length(static_cast<unsigned char>(text[i]));
        if (len == 0 || i + len > text.size()) {
            break;
        }
        i += len;
        ++count;
    }
    return count;
}

std::string limitCodePoints(const std::string& text, int maxPoints) {
    if (maxPoints <= 0) {
        return {};
    }
    std::string out;
    int count = 0;
    for (size_t i = 0; i < text.size() && count < maxPoints;) {
        const size_t len = utf8Length(static_cast<unsigned char>(text[i]));
        if (len == 0 || i + len > text.size()) {
            break;
        }
        out.append(text, i, len);
        i += len;
        ++count;
    }
    return out;
}

std::string truncateWithEllipsis(const std::string& text, int maxPoints) {
    if (codePointCount(text) <= maxPoints) {
        return text;
    }
    if (maxPoints <= 1) {
        return "…";
    }
    return limitCodePoints(text, maxPoints - 1) + "…";
}

std::string groupDigits(int value) {
    const std::string digits = std::to_string(value);
    std::string out;
    const int n = static_cast<int>(digits.size());
    for (int i = 0; i < n; ++i) {
        if (i > 0 && (n - i) % 3 == 0) {
            out.push_back(',');
        }
        out.push_back(digits[static_cast<size_t>(i)]);
    }
    return out;
}

std::string joinMenu(const std::string& title, const std::string& rest) {
    const std::string name = trim(title);
    if (name.empty()) {
        return rest;
    }
    constexpr int kMaxPoints = 32;
    const int restPoints = codePointCount(rest);
    const int budget = kMaxPoints - 1 - restPoints;
    if (budget < 1) {
        return rest;
    }
    return truncateWithEllipsis(name, budget) + " " + rest;
}

std::string formatDate(CivilDate date) {
    static const char* kWeekdays[] = {"Sunday", "Monday", "Tuesday", "Wednesday",
                                      "Thursday", "Friday", "Saturday"};
    static const char* kMonths[] = {"January", "February", "March", "April",
                                    "May", "June", "July", "August",
                                    "September", "October", "November", "December"};
    const int weekday = weekdaySunday0(date);
    return std::string(kWeekdays[weekday]) + ", " + kMonths[date.month - 1] + " " +
           std::to_string(date.day) + ", " + std::to_string(date.year);
}

std::string countPhrase(int count, const char* singular, const char* plural) {
    return groupDigits(count) + " " + (count == 1 ? singular : plural);
}

std::string menuLabelFor(const std::string& title, const std::string& rest, bool includeTitle) {
    if (!includeTitle) {
        return rest;
    }
    return joinMenu(title, rest);
}

void appendCodepoint(std::string& out, int cp) {
    if (cp < 0 || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF)) {
        return;
    }
    if (cp < 0x80) {
        out.push_back(static_cast<char>(cp));
    } else if (cp < 0x800) {
        out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
        out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else if (cp < 0x10000) {
        out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
        out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
        out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else {
        out.push_back(static_cast<char>(0xF0 | (cp >> 18)));
        out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
        out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
        out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    }
}

std::string escapeJson(const std::string& text) {
    std::string out;
    out.reserve(text.size());
    for (unsigned char c : text) {
        switch (c) {
            case '"':
                out += "\\\"";
                break;
            case '\\':
                out += "\\\\";
                break;
            case '\b':
                out += "\\b";
                break;
            case '\f':
                out += "\\f";
                break;
            case '\n':
                out += "\\n";
                break;
            case '\r':
                out += "\\r";
                break;
            case '\t':
                out += "\\t";
                break;
            default:
                if (c < 0x20) {
                    constexpr char kHex[] = "0123456789abcdef";
                    out += "\\u00";
                    out.push_back(kHex[c >> 4]);
                    out.push_back(kHex[c & 0x0F]);
                } else {
                    out.push_back(static_cast<char>(c));
                }
                break;
        }
    }
    return out;
}

bool isGoalId(const std::string& id) {
    if (id.empty() || id.size() > 64) {
        return false;
    }
    for (unsigned char c : id) {
        if (!std::isalnum(c) && c != '-' && c != '_') {
            return false;
        }
    }
    return true;
}

class JsonParser {
public:
    explicit JsonParser(std::string text) : text_(std::move(text)) {
        if (text_.size() >= 3 && static_cast<unsigned char>(text_[0]) == 0xEF &&
            static_cast<unsigned char>(text_[1]) == 0xBB &&
            static_cast<unsigned char>(text_[2]) == 0xBF) {
            text_.erase(0, 3);
        }
    }

    bool parse(Event& event) {
        skip();
        if (!consume('{')) {
            return false;
        }
        bool sawTitle = false;
        bool sawYear = false;
        bool sawMonth = false;
        bool sawDay = false;
        skip();
        if (peek('}')) {
            return false;
        }
        while (true) {
            std::string key;
            if (!parseString(key) || !consume(':')) {
                return false;
            }
            if (key == "title") {
                if (sawTitle || !parseString(event.title)) {
                    return false;
                }
                sawTitle = true;
            } else if (key == "year") {
                if (sawYear || !parseInt(event.date.year)) {
                    return false;
                }
                sawYear = true;
            } else if (key == "month") {
                if (sawMonth || !parseInt(event.date.month)) {
                    return false;
                }
                sawMonth = true;
            } else if (key == "day") {
                if (sawDay || !parseInt(event.date.day)) {
                    return false;
                }
                sawDay = true;
            } else {
                return false;
            }
            skip();
            if (consume('}')) {
                break;
            }
            if (!consume(',')) {
                return false;
            }
        }
        skip();
        return index_ == text_.size() && sawTitle && sawYear && sawMonth && sawDay &&
               isValidDate(event.date);
    }

    bool parse(std::vector<Goal>& goals) {
        goals.clear();
        skip();
        if (!consume('{')) {
            return false;
        }
        bool sawGoals = false;
        skip();
        if (peek('}')) {
            return false;
        }
        while (true) {
            std::string key;
            if (!parseString(key) || !consume(':')) {
                return false;
            }
            if (key == "goals") {
                if (sawGoals || !parseGoalArray(goals)) {
                    return false;
                }
                sawGoals = true;
            } else {
                return false;
            }
            skip();
            if (consume('}')) {
                break;
            }
            if (!consume(',')) {
                return false;
            }
        }
        skip();
        return index_ == text_.size() && sawGoals;
    }

private:
    bool parseGoalArray(std::vector<Goal>& goals) {
        if (!consume('[')) {
            return false;
        }
        skip();
        if (consume(']')) {
            return true;
        }
        while (true) {
            Goal goal;
            if (!parseGoal(goal)) {
                return false;
            }
            goals.push_back(std::move(goal));
            if (goals.size() > 100) {
                return false;
            }
            skip();
            if (consume(']')) {
                return true;
            }
            if (!consume(',')) {
                return false;
            }
        }
    }

    bool parseGoal(Goal& goal) {
        if (!consume('{')) {
            return false;
        }
        bool sawId = false;
        bool sawTitle = false;
        bool sawDone = false;
        skip();
        if (peek('}')) {
            return false;
        }
        while (true) {
            std::string key;
            if (!parseString(key) || !consume(':')) {
                return false;
            }
            if (key == "id") {
                if (sawId || !parseString(goal.id)) {
                    return false;
                }
                sawId = true;
            } else if (key == "title") {
                if (sawTitle || !parseString(goal.title)) {
                    return false;
                }
                sawTitle = true;
            } else if (key == "done") {
                if (sawDone || !parseBool(goal.done)) {
                    return false;
                }
                sawDone = true;
            } else {
                return false;
            }
            skip();
            if (consume('}')) {
                break;
            }
            if (!consume(',')) {
                return false;
            }
        }
        goal.id = trim(goal.id);
        goal.title = trim(goal.title);
        return sawId && sawTitle && sawDone && isGoalId(goal.id) && !goal.title.empty();
    }

    bool parseBool(bool& out) {
        skip();
        if (text_.compare(index_, 4, "true") == 0 && !isIdChar(at(index_ + 4))) {
            index_ += 4;
            out = true;
            return true;
        }
        if (text_.compare(index_, 5, "false") == 0 && !isIdChar(at(index_ + 5))) {
            index_ += 5;
            out = false;
            return true;
        }
        return false;
    }

    char at(size_t index) const {
        return index < text_.size() ? text_[index] : '\0';
    }

    static bool isIdChar(char c) {
        const unsigned char value = static_cast<unsigned char>(c);
        return std::isalnum(value) || c == '-' || c == '_';
    }
    void skip() {
        while (index_ < text_.size() &&
               std::isspace(static_cast<unsigned char>(text_[index_]))) {
            ++index_;
        }
    }

    bool peek(char expected) {
        skip();
        return index_ < text_.size() && text_[index_] == expected;
    }

    bool consume(char expected) {
        skip();
        if (index_ < text_.size() && text_[index_] == expected) {
            ++index_;
            return true;
        }
        return false;
    }

    bool parseString(std::string& out) {
        if (!consume('"')) {
            return false;
        }
        out.clear();
        while (index_ < text_.size()) {
            const char c = text_[index_++];
            if (c == '"') {
                return true;
            }
            if (static_cast<unsigned char>(c) < 0x20) {
                return false;
            }
            if (c != '\\') {
                out.push_back(c);
                continue;
            }
            if (index_ >= text_.size()) {
                return false;
            }
            const char escaped = text_[index_++];
            switch (escaped) {
                case '"':
                case '\\':
                case '/':
                    out.push_back(escaped);
                    break;
                case 'b':
                    out.push_back('\b');
                    break;
                case 'f':
                    out.push_back('\f');
                    break;
                case 'n':
                    out.push_back('\n');
                    break;
                case 'r':
                    out.push_back('\r');
                    break;
                case 't':
                    out.push_back('\t');
                    break;
                case 'u': {
                    int cp = parseHex4();
                    if (cp < 0) {
                        return false;
                    }
                    if (cp >= 0xD800 && cp <= 0xDBFF) {
                        if (index_ + 1 >= text_.size() || text_[index_] != '\\' ||
                            text_[index_ + 1] != 'u') {
                            return false;
                        }
                        index_ += 2;
                        const int low = parseHex4();
                        if (low < 0xDC00 || low > 0xDFFF) {
                            return false;
                        }
                        cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00);
                    } else if (cp >= 0xDC00 && cp <= 0xDFFF) {
                        return false;
                    }
                    appendCodepoint(out, cp);
                    break;
                }
                default:
                    return false;
            }
        }
        return false;
    }

    int parseHex4() {
        if (index_ + 4 > text_.size()) {
            return -1;
        }
        int value = 0;
        for (int i = 0; i < 4; ++i) {
            const char h = text_[index_++];
            value <<= 4;
            if (h >= '0' && h <= '9') {
                value += h - '0';
            } else if (h >= 'a' && h <= 'f') {
                value += h - 'a' + 10;
            } else if (h >= 'A' && h <= 'F') {
                value += h - 'A' + 10;
            } else {
                return -1;
            }
        }
        return value;
    }

    bool parseInt(int& out) {
        skip();
        if (index_ >= text_.size()) {
            return false;
        }
        int sign = 1;
        if (text_[index_] == '-') {
            sign = -1;
            ++index_;
        }
        if (index_ >= text_.size() ||
            !std::isdigit(static_cast<unsigned char>(text_[index_]))) {
            return false;
        }
        long value = 0;
        while (index_ < text_.size() &&
               std::isdigit(static_cast<unsigned char>(text_[index_]))) {
            value = value * 10 + (text_[index_] - '0');
            if (value > 100000000) {
                return false;
            }
            ++index_;
        }
        out = static_cast<int>(value * sign);
        return true;
    }

    std::string text_;
    size_t index_ = 0;
};

}  // namespace

bool isValidDate(CivilDate date) {
    if (date.year < 1 || date.year > 9999 || date.month < 1 || date.month > 12) {
        return false;
    }
    static const int kDays[] = {0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    int days = kDays[date.month];
    if (date.month == 2 && isLeapYear(date.year)) {
        days = 29;
    }
    return date.day >= 1 && date.day <= days;
}

int daysBetween(CivilDate from, CivilDate to) {
    if (!isValidDate(from) || !isValidDate(to)) {
        return 0;
    }
    return daysFromCivil(to.year, to.month, to.day) -
           daysFromCivil(from.year, from.month, from.day);
}

CivilDate todayLocal() {
    const std::time_t now = std::time(nullptr);
    std::tm local {};
    if (localtime_r(&now, &local) == nullptr) {
        return {};
    }
    return CivilDate {local.tm_year + 1900, local.tm_mon + 1, local.tm_mday};
}

Presentation present(const std::optional<Event>& event, CivilDate today, MenuStyle style) {
    Presentation result;
    if (!event || !isValidDate(event->date) || !isValidDate(today)) {
        result.menuLabel = "Set date";
        result.tooltip = "Click to choose a countdown date";
        result.kicker = "No countdown yet";
        result.headline = "Not set";
        result.dateLine = "Pick a date. The menu bar will show the days left.";
        return result;
    }

    const std::string title = trim(event->title);
    result.configured = true;
    result.dayDelta = daysBetween(today, event->date);
    result.dateLine = formatDate(event->date);
    const int distance = result.dayDelta > 0 ? result.dayDelta : -result.dayDelta;
    const std::string count = groupDigits(distance);

    if (result.dayDelta > 0) {
        const std::string rest = countPhrase(distance, "day", "days");
        result.headline = count;
        result.unit = distance == 1 ? "day" : "days";
        result.kicker = title.empty() ? "Days left" : "Until " + title;
        result.menuLabel = menuLabelFor(title, rest, style.includeTitle);
        result.tooltip = title.empty() ? rest + " left · " + result.dateLine
                                        : rest + " until " + title + " · " + result.dateLine;
    } else if (result.dayDelta == 0) {
        result.headline = "Today";
        result.kicker = title.empty() ? "That's today" : title + " is today";
        result.menuLabel = menuLabelFor(title, "today", style.includeTitle);
        result.tooltip = result.kicker + " · " + result.dateLine;
    } else {
        const std::string rest = countPhrase(distance, "day ago", "days ago");
        result.headline = count;
        result.unit = distance == 1 ? "day ago" : "days ago";
        result.kicker = title.empty() ? "Days since" : "Since " + title;
        result.menuLabel = menuLabelFor(title, rest, style.includeTitle);
        result.tooltip = title.empty() ? rest + " · " + result.dateLine
                                        : rest + " since " + title + " · " + result.dateLine;
    }
    return result;
}

Store::Store(std::filesystem::path file) : file_(std::move(file)) {}

std::optional<Event> Store::load() const {
    std::ifstream input(file_, std::ios::binary);
    if (!input) {
        return std::nullopt;
    }
    std::string data((std::istreambuf_iterator<char>(input)), std::istreambuf_iterator<char>());
    if (data.size() > 65536) {
        return std::nullopt;
    }
    Event event;
    JsonParser parser(std::move(data));
    if (!parser.parse(event)) {
        return std::nullopt;
    }
    event.title = trim(event.title);
    return event;
}

bool Store::save(const Event& event) const {
    if (!isValidDate(event.date)) {
        return false;
    }
    const std::string title = limitCodePoints(trim(event.title), 40);
    std::error_code error;
    if (!file_.parent_path().empty()) {
        std::filesystem::create_directories(file_.parent_path(), error);
        if (error) {
            return false;
        }
    }
    const std::string json = "{\n  \"title\": \"" + escapeJson(title) +
                             "\",\n  \"year\": " + std::to_string(event.date.year) +
                             ",\n  \"month\": " + std::to_string(event.date.month) +
                             ",\n  \"day\": " + std::to_string(event.date.day) + "\n}\n";
    const std::filesystem::path temporary = file_.native() + ".tmp";
    {
        std::ofstream output(temporary, std::ios::binary | std::ios::trunc);
        if (!output) {
            return false;
        }
        output << json;
        if (!output.good()) {
            return false;
        }
    }
    std::filesystem::rename(temporary, file_, error);
    return !error;
}

bool Store::clear() const {
    std::error_code error;
    std::filesystem::remove(file_, error);
    return !error;
}

std::string makeGoalId() {
    static constexpr char kHex[] = "0123456789abcdef";
    std::random_device device;
    std::uniform_int_distribution<int> dist(0, 15);
    std::string id(16, '0');
    for (char& character : id) {
        character = kHex[dist(device)];
    }
    return id;
}

namespace {

std::vector<Goal> normalizedGoals(const std::vector<Goal>& goals, bool& ok) {
    ok = goals.size() <= 100;
    std::vector<Goal> cleaned;
    std::unordered_set<std::string> seen;
    if (!ok) {
        return cleaned;
    }
    cleaned.reserve(goals.size());
    for (const Goal& goal : goals) {
        Goal item;
        item.id = trim(goal.id);
        item.title = limitCodePoints(trim(goal.title), 80);
        item.done = goal.done;
        if (!isGoalId(item.id) || item.title.empty() || !seen.insert(item.id).second) {
            ok = false;
            return {};
        }
        cleaned.push_back(std::move(item));
    }
    return cleaned;
}

}  // namespace

GoalStore::GoalStore(std::filesystem::path file) : file_(std::move(file)) {}

std::optional<std::vector<Goal>> GoalStore::load() const {
    std::error_code error;
    const bool present = std::filesystem::exists(file_, error);
    if (error) {
        return std::nullopt;
    }
    if (!present) {
        return std::vector<Goal> {};
    }
    std::ifstream input(file_, std::ios::binary);
    if (!input) {
        return std::nullopt;
    }
    std::string data((std::istreambuf_iterator<char>(input)), std::istreambuf_iterator<char>());
    if (data.size() > 262144) {
        return std::nullopt;
    }
    std::vector<Goal> goals;
    JsonParser parser(std::move(data));
    if (!parser.parse(goals)) {
        return std::nullopt;
    }
    bool ok = false;
    std::vector<Goal> cleaned = normalizedGoals(goals, ok);
    if (!ok) {
        return std::nullopt;
    }
    return cleaned;
}

bool GoalStore::save(const std::vector<Goal>& goals) const {
    bool ok = false;
    const std::vector<Goal> cleaned = normalizedGoals(goals, ok);
    if (!ok) {
        return false;
    }
    std::error_code error;
    if (!file_.parent_path().empty()) {
        std::filesystem::create_directories(file_.parent_path(), error);
        if (error) {
            return false;
        }
    }
    std::string json = "{\n  \"goals\": [";
    if (cleaned.empty()) {
        json += "]\n}\n";
    } else {
        json += "\n";
        for (size_t index = 0; index < cleaned.size(); ++index) {
            const Goal& goal = cleaned[index];
            json += "    {\n      \"id\": \"" + escapeJson(goal.id) + "\",\n      \"title\": \"" +
                    escapeJson(goal.title) + "\",\n      \"done\": ";
            json += goal.done ? "true" : "false";
            json += "\n    }";
            if (index + 1 < cleaned.size()) {
                json += ",";
            }
            json += "\n";
        }
        json += "  ]\n}\n";
    }
    const std::filesystem::path temporary = file_.native() + ".tmp";
    {
        std::ofstream output(temporary, std::ios::binary | std::ios::trunc);
        if (!output) {
            return false;
        }
        output << json;
        if (!output.good()) {
            return false;
        }
    }
    std::filesystem::rename(temporary, file_, error);
    return !error;
}

}  // namespace countcount
