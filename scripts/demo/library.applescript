use framework "Foundation"
use scripting additions

-- Bulk property reads keep Apple Events proportional to columns, not tracks.
tell application "Music"
    tell library playlist 1
        set columns to {persistent ID of every track, name of every track, artist of every track, album of every track, duration of every track}
    end tell
end tell
set jsonData to current application's NSJSONSerialization's dataWithJSONObject:columns options:0 |error|:(missing value)
if jsonData is missing value then error "Music returned library metadata that could not be serialized."
return (current application's NSString's alloc()'s initWithData:jsonData encoding:(current application's NSUTF8StringEncoding)) as text
