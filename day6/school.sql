PRAGMA foreign_keys = ON;

-- 1. Students
CREATE TABLE students (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE
);

-- 2. Courses
CREATE TABLE courses (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);

-- 3. Enrolments
CREATE TABLE enrolments (
    id INTEGER PRIMARY KEY,
    student_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    grade TEXT,
    FOREIGN KEY (student_id) REFERENCES students(id),
    FOREIGN KEY (course_id) REFERENCES courses(id),
    UNIQUE (student_id, course_id)
);

-- Sample students
INSERT INTO students (id, name, email) VALUES
(1, 'Alice Wanjiku', 'alice@example.com'),
(2, 'Brian Otieno', 'brian@example.com'),
(3, 'Carol Achieng', 'carol@example.com'),
(4, 'David Kamau', 'david@example.com');

-- Sample courses
INSERT INTO courses (id, name) VALUES
(1, 'Database Systems'),
(2, 'Web Development'),
(3, 'Computer Networks');

-- Sample enrolments
INSERT INTO enrolments (id, student_id, course_id, grade) VALUES
(1, 1, 1, 'A'),
(2, 1, 2, 'B'),
(3, 2, 1, 'B'),
(4, 2, 3, 'A'),
(5, 3, 2, 'A');

-- Query 1: All courses for one student by name
SELECT courses.name AS course
FROM courses
JOIN enrolments ON courses.id = enrolments.course_id
JOIN students ON students.id = enrolments.student_id
WHERE students.name = 'Alice Wanjiku';

-- Query 2: All students on one course
SELECT students.name AS student
FROM students
JOIN enrolments ON students.id = enrolments.student_id
JOIN courses ON courses.id = enrolments.course_id
WHERE courses.name = 'Database Systems';

-- Query 3: Number of students per course
SELECT courses.name AS course, COUNT(enrolments.student_id) AS student_count
FROM courses
LEFT JOIN enrolments ON courses.id = enrolments.course_id
GROUP BY courses.id, courses.name;

-- Query 4: Students who have no enrolments
SELECT students.name
FROM students
LEFT JOIN enrolments ON students.id = enrolments.student_id
WHERE enrolments.id IS NULL;

-- Query 5: Update one enrolment's grade
UPDATE enrolments
SET grade = 'A+'
WHERE enrolments.student_id = 2 AND enrolments.course_id = 1;

-- Check the updated grade
SELECT students.name AS student, courses.name AS course, enrolments.grade
FROM enrolments
JOIN students ON students.id = enrolments.student_id
JOIN courses ON courses.id = enrolments.course_id
WHERE enrolments.student_id = 2 AND enrolments.course_id = 1;
