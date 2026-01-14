//
//  SchedulerV2.swift
//  Booksmart
//
//  Created by Felix Marianayagam on 05/01/23.
//

import Foundation
import RealmSwift

/*
message SchedTimingTodayResponse {
  uint32 days_elapsed = 1;
  int64 next_day_at = 2;
}
*/

final class Scheduler {
    typealias CardId = ObjectId // This is the flashcardDB.id.
    typealias DeckId = ObjectId // This is the documentDB.id.

    /* Looks like these variables may not be needed.
    version = 2
    name = "std2"
    haveCustomStudy = True
    _burySiblingsOnAnswer = True
    revCount: int
    */
    
    private var col: [Card] = []
    private var queueLimit = 0
    private var reportLimit = 0
    private var dynReportLimit = 0
    private var reps = 0
    private var _haveQueues = false
    private var _lrnCutoff = 0
    private var _active_decks: [DeckId] = []
    private var _current_deck_id: DeckId!

    private var lrnCount = 0

    
    private var _lrnQueue: [(Int, CardId)] = []
    private var _lrnDayQueue: [CardId] = []
    private var _lrnDids: [CardId] = []

    
    // From base.py
    private var day_cutoff: Int {
        /*
        def day_cutoff(self) -> int:
            return self._timing_today().next_day_at
        */
        // self.day_cutoff references SchedTimingTodayResponse.
        // From Anki Default Settings - Next day starts at 4 hours past midnight.
        // From pub fn sched_timing_today_v2_new.
        /*
         let rollover_today_datetime = rollover_datetime(now_datetime, rollover_hour);
         let rollover_passed = rollover_today_datetime <= now_datetime;
         let next_day_at = TimestampSecs(if rollover_passed {
         (rollover_today_datetime + Duration::days(1)).timestamp()
         } else {
         rollover_today_datetime.timestamp()
         });
         */
        // TODO: In progress.
        return 0
    }

    private var today: Int {
        /*
        @property
        def today(self) -> int:
            return self._timing_today().days_elapsed
        */
        // TODO: In progress.
        return 0
    }

    init(cards: [Card], documentId: ObjectId) {
        /*
        def __init__(self, col: anki.collection.Collection) -> None:
            super().__init__(col)
            self.queueLimit = 50
            self.reportLimit = 1000
            self.dynReportLimit = 99999
            self.reps = 0
            self._haveQueues = False
            self._lrnCutoff = 0
            self._active_decks: list[DeckId] = []
            self._current_deck_id = DeckId(1)
        */
        self.col = cards
        self.queueLimit = 50
        self.reportLimit = 1000
        self.dynReportLimit = 99999
        self.reps = 0
        self._haveQueues = false
        self._lrnCutoff = 0
        // Assuming we have only one deck per document, active_deck refers to documentDB.id from which the flashcards are retrieved.
        self._active_decks = [documentId]
        self._current_deck_id = documentId
    }

    // Daily cutoff
    // ##########################################################################

    func updateCutoff() {
        // Empty function. Why is this needed?
        /*
        def _updateCutoff(self) -> None:
            pass
        */
    }

    func _checkDay() {
        /*
        def _checkDay(self) -> None:
        # check if the day has rolled over
        if time.time() > self.day_cutoff:
        self.reset()
        */

        // TODO: In progress.
        /*
        if Date.now > day_cutoff {
            self.reset()
        }
        */
    }

    // Fetching the next card
    // ##########################################################################

    func reset() {
        /*
        def reset(self) -> None:
            self._current_deck_id = self.col.decks.selected()
            self._update_active_decks()
            self._reset_counts()
            self._resetLrn()
            self._resetRev()
            self._resetNew()
            self._haveQueues = True
        */
        self._haveQueues = true
    }

    // What is node that's referenced in the below function? Skip for now.
    /*
    def _reset_counts(self) -> None:
        node = self.deck_due_tree(self._current_deck_id)
        if not node:
            # current deck points to a missing deck
            self.newCount = 0
            self.revCount = 0
            self._immediate_learn_count = 0
        else:
            self.newCount = node.new_count
            self.revCount = node.review_count
            self._immediate_learn_count = node.learn_count
    */

    func getCard() -> Card? {
        /*
        def getCard(self) -> Card | None:
            """Pop the next card from the queue. None if finished."""
            self._checkDay()
            if not self._haveQueues:
                self.reset()
            card = self._getCard()
            if card:
                if not self._burySiblingsOnAnswer:
                    self._burySiblings(card)
                card.start_timer()
                return card
            return None
        */

        // Pop the next card from the queue. None if finished.
        _checkDay()
        if !self._haveQueues {
            self.reset()
        }
        if let card = self._getCard() {
            // What are siblings in the below code? Skip for now.
            /*
            if not self._burySiblingsOnAnswer:
                self._burySiblings(card)
            card.start_timer()
            */
            return card
        }
        return nil
    }

    func _getCard() -> Card? {
        /*
        def _getCard(self) -> Card | None:
            """Return the next due card, or None."""
            # learning card due?
            c = self._getLrnCard()
            if c:
                return c

            # new first, or time for one?
            if self._timeForNewCard():
                c = self._getNewCard()
                if c:
                    return c

            # day learning first and card due?
            dayLearnFirst = self.col.conf.get("dayLearnFirst", False)
            if dayLearnFirst:
                c = self._getLrnDayCard()
                if c:
                    return c

            # card due for review?
            c = self._getRevCard()
            if c:
                return c

            # day learning card due?
            if not dayLearnFirst:
                c = self._getLrnDayCard()
                if c:
                    return c

            # new cards left?
            c = self._getNewCard()
            if c:
                return c

            # collapse or finish
            return self._getLrnCard(collapse=True)
        */
        
        // learning card due?
        if let c = self._getLrnCard() {
            return c
        }

        // Return the next due card, or None.
        return nil
    }

    // # Fetching learning cards
    // ##########################################################################

    @discardableResult
    func _updateLrnCutoff(force: Bool) -> Bool {
        /*
        # scan for any newly due learning cards every minute
        def _updateLrnCutoff(self, force: bool) -> bool:
            nextCutoff = int_time() + self.col.conf["collapseTime"]
            if nextCutoff - self._lrnCutoff > 60 or force:
                self._lrnCutoff = nextCutoff
                return True
            return False
        */
        let nextCutoff = utils.int_time() + conf.collapseTime
        if nextCutoff - self._lrnCutoff > 60 || force {
            self._lrnCutoff = nextCutoff
            return true
        }
        return false
    }

    func _maybeResetLrn(force: Bool) {
        /*
        def _maybeResetLrn(self, force: bool) -> None:
            if self._updateLrnCutoff(force):
                self._resetLrn()
        */
        if self._updateLrnCutoff(force: force) {
            self._resetLrn()
        }
    }

    func _resetLrnCount() {
        /*
        def _resetLrnCount(self) -> None:
            # sub-day
            self.lrnCount = (
                self.col.db.scalar(
                    f"""select count() from cards where did in %s and queue = {QUEUE_TYPE_LRN} and due < ?"""
                    % (self._deck_limit()),
                    self._lrnCutoff,
                )
                or 0
            )
            # day
            self.lrnCount += self.col.db.scalar(
                f"""select count() from cards where did in %s and queue = {QUEUE_TYPE_DAY_LEARN_RELEARN} and due <= ?"""
                % (self._deck_limit()),
                self.today,
            )
            # previews
            self.lrnCount += self.col.db.scalar(
                f"""select count() from cards where did in %s and queue = {QUEUE_TYPE_PREVIEW}"""
                % (self._deck_limit())
            )
        */

        // Notes:
        // "did in %s" in the above query refers to deck id. I'm assuming there'd be only one deck per document and hence not using deck id.

        // sub-day
        self.lrnCount = self.col.filter({ $0.queue == CardQueue.QUEUE_TYPE_LRN && $0.due < self._lrnCutoff }).count
        // day
        self.lrnCount += self.col.filter({ $0.queue == CardQueue.QUEUE_TYPE_DAY_LEARN_RELEARN && $0.due <= self.today }).count
        // previews
        self.lrnCount += self.col.filter({ $0.queue == CardQueue.QUEUE_TYPE_PREVIEW }).count
    }
    
    func _resetLrn() {
        /*
        def _resetLrn(self) -> None:
            self._updateLrnCutoff(force=True)
            self._resetLrnCount()
            self._lrnQueue: list[tuple[int, CardId]] = []
            self._lrnDayQueue: list[CardId] = []
            self._lrnDids = self.col.decks.active()[:]
        */
        self._updateLrnCutoff(force: true)
        self._resetLrnCount()
        self._lrnQueue = []
        self._lrnDayQueue = []
        self._lrnDids = _active_decks
    }

    // sub-day learning
    func _fillLrn() -> Bool {
        /*
        # sub-day learning
        def _fillLrn(self) -> bool | list[Any]:
            if not self.lrnCount:
                return False
            if self._lrnQueue:
                return True
            cutoff = int_time() + self.col.conf["collapseTime"]
            self._lrnQueue = self.col.db.all(  # type: ignore
                f"""
    select due, id from cards where
    did in %s and queue in ({QUEUE_TYPE_LRN},{QUEUE_TYPE_PREVIEW}) and due < ?
    limit %d"""
                % (self._deck_limit(), self.reportLimit),
                cutoff,
            )
            self._lrnQueue = [cast(tuple[int, CardId], tuple(e)) for e in self._lrnQueue]
            # as it arrives sorted by did first, we need to sort it
            self._lrnQueue.sort()
            return self._lrnQueue
        */

        // Notes:
        // The function returns "bool | list[Any]". Just using bool since the list returned can be accessed using self.
        // # type: ignore - Ignore type error. Looks like it's not needed in swift. Wonder, if there's any catch and hence making a note.
        // "did in %s" in the above query refers to deck id. I'm assuming there'd be only one deck per document and hence not using deck id.

        if self.lrnCount == 0 {
            return false
        }
        if self._lrnQueue.count > 0 {
            return true
        }
        let cutoff = utils.int_time() + conf.collapseTime
        self._lrnQueue = self.col
            .filter({ ($0.queue == CardQueue.QUEUE_TYPE_LRN || $0.queue == CardQueue.QUEUE_TYPE_PREVIEW) && $0.due < cutoff })
            .prefix(self.reportLimit)
            .map({ ($0.due, $0.id) })
        // did is not used and the queue is not sorted by did first. Therefore, commenting the below line.
        // self._lrnQueue.sort()
        return true
    }

    func _getLrnCard(collapse: Bool = false) -> Card? {
        /*
        def _getLrnCard(self, collapse: bool = False) -> Card | None:
            self._maybeResetLrn(force=collapse and self.lrnCount == 0)
            if self._fillLrn():
                cutoff = time.time()
                if collapse:
                    cutoff += self.col.conf["collapseTime"]
                if self._lrnQueue[0][0] < cutoff:
                    id = heappop(self._lrnQueue)[1]
                    card = self.col.get_card(id)
                    self.lrnCount -= 1
                    return card
            return None
        */
        
        self._maybeResetLrn(force: collapse && self.lrnCount == 0)
        if self._fillLrn() {
            var cutoff = Time.time()
            if collapse {
                cutoff += conf.collapseTime
            }
            // TODO: Convert below code.
            // if self._lrnQueue[0][0] < cutoff:
        }
        return nil
    }

    // # daily learning
    func _fillLrnDay() -> Bool {
        /*
        def _fillLrnDay(self) -> bool | None:
            if not self.lrnCount:
                return False
            if self._lrnDayQueue:
                return True
            while self._lrnDids:
                did = self._lrnDids[0]
                # fill the queue with the current did
                self._lrnDayQueue = self.col.db.list(
                    f"""
    select id from cards where
    did = ? and queue = {QUEUE_TYPE_DAY_LEARN_RELEARN} and due <= ? limit ?""",
                    did,
                    self.today,
                    self.queueLimit,
                )
                if self._lrnDayQueue:
                    # order
                    r = random.Random()
                    r.seed(self.today)
                    r.shuffle(self._lrnDayQueue)
                    # is the current did empty?
                    if len(self._lrnDayQueue) < self.queueLimit:
                        self._lrnDids.pop(0)
                    return True
                # nothing left in the deck; move to next
                self._lrnDids.pop(0)
            # shouldn't reach here
            return False
        */

        if self.lrnCount == 0 {
            return false
        }
        if self._lrnDayQueue.count > 0 {
            return true
        }

        while self._lrnDids.count > 0 {
            let did = self._lrnDids[0]
            // # fill the queue with the current did
            self._lrnDayQueue = self.col
                .filter({ $0.did == did && $0.queue == CardQueue.QUEUE_TYPE_DAY_LEARN_RELEARN && $0.due <= self.today })
                .prefix(self.queueLimit)
                .map({ $0.id })
            
            if self._lrnDayQueue.count > 0 {
                // # order
                var random = Random(seed: self.today)
                self._lrnDayQueue.shuffle(using: &random)
                // # is the current did empty?
                if self._lrnDayQueue.count < self.queueLimit {
                    self._lrnDids.remove(at: 0)
                }
                return true
            }
            // nothing left in the deck; move to next
            self._lrnDids.remove(at: 0)
        }
        
        // # shouldn't reach here
        return false
    }

    func _deck_limit() -> String {
        /*
        def _deck_limit(self) -> str:
            return ids2str(self.col.decks.active())
        */
        return utils.ids2str(ids: self._active_decks)
    }

    static func getCards(for documentId: ObjectId) -> [Card] {
        // Retrieve flash cards from realm for the given documentId. Use for testing.
        return [Card]()
    }
}


// Placeholder card struct, should be revised to work with FlashcardDB and properties to be added later.
struct Card {
    var id = ObjectId.generate()
    var did = ObjectId.generate() // Corresponds to the documentId.
    var queue: CardQueue = .QUEUE_TYPE_LRN
    // This corresponds to the date when the card is due for study.
    var due: Int = 0
}
