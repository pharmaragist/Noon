# Store

The Noon Store: browse Providers, preview Content, and install it into the desktop.

## Language

**Provider**:
A named source of Content, either OCS (kde-store, pling) or a Static Hub.
_Avoid_: backend, server

**Content**:
A single installable entry with Previews and Downloads.
_Avoid_: item, package

**Category**:
A grouping of Content inside a Provider, used for browsing and filtering.
_Avoid_: section, chip

**Kind**:
The install destination family: icon-theme, cursor-theme, noon-plugin. Go owns the truth; QML renders from it.
_Avoid_: type, xdgType

**Static Hub**:
A Provider backed by a plain JSON index instead of OCS.
_Avoid_: custom provider

**Preview**:
An image representing Content; the size word (default vs small) selects the variant.
_Avoid_: thumbnail, screenshot

**Install Queue**:
The ordered list of install intents with exactly one active at a time.
_Avoid_: download queue, dlQueue
