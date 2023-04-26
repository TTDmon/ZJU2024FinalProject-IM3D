//
//  Queue.swift
//  IOSCaptureSwiftUI
//
//  Created by Fenghe Xu on 2021/11/4.
//

import Foundation

public protocol Queue {
    associatedtype Element
    mutating func enqueue(_ element: Element) -> Bool
    mutating func dequeue() -> Element?
    var isEmpty: Bool { get }
    var peek: Element? { get }
}

public class QueueStack<T> : Queue {
    private var leftStack: [T] = []
    private var rightStack: [T] = []
    public init() {}
    
    public var isEmpty: Bool {
        leftStack.isEmpty && rightStack.isEmpty
    }
    
    public var peek: T? {
        !leftStack.isEmpty ? leftStack.last : rightStack.first
    }
    
    public var size: Int {
        leftStack.count + rightStack.count
    }
    
    public func enqueue(_ element: T) -> Bool {
        rightStack.append(element)
        return true
    }
    
    public func dequeue() -> T? {
        if leftStack.isEmpty {
            leftStack = rightStack.reversed()
            rightStack.removeAll()
        }
        return leftStack.popLast()
    }
}

/*
 This queue guarantees thread safety when there is only one consumer
 */
public class ConcurrentQueue<T> {
    var queue = QueueStack<T>()
    var mutex = DispatchSemaphore(value: 1)
    
    public init() {}
    
    // Single Consumer safe 
    public var isEmpty: Bool {
        mutex.wait()
        let ret = queue.isEmpty
        mutex.signal()
        return ret
    }
    
    public var peek: T? {
        mutex.wait()
        let ret = queue.peek
        mutex.signal()
        return ret
    }
    
    public var size: Int {
        mutex.wait()
        let ret = queue.size
        mutex.signal()
        return ret
    }
    
    public func enqueue(_ element: T) -> Bool {
        mutex.wait()
        let ret = queue.enqueue(element)
        mutex.signal()
        return ret
    }
    
    public func dequeue() -> T? {
        mutex.wait()
        let ret = queue.dequeue()
        mutex.signal()
        return ret
    }
}
