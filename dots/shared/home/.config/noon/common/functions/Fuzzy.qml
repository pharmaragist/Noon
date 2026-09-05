pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import "fuzzysort.js" as FuzzySort

Singleton {
    function go(...args) {
        return FuzzySort.go(...args);
    }

    function prepare(...args) {
        return FuzzySort.prepare(...args);
    }
}
