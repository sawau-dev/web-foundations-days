# School Database Design

## Students Table

The `students` table stores information about each student. It contains the student's ID, name, and email address. The ID is the primary key, while the email address is UNIQUE so that two students cannot use the same email address.

## Courses Table

The `courses` table stores the courses offered by the school. Each course has an ID and a name. The ID is the primary key.

## Enrolments Table

The `enrolments` table records which students are enrolled in which courses. It contains foreign keys pointing to the students and courses tables. It also stores the student's grade for the course.

## Relationships

There is a one-to-many relationship between students and enrolments because one student can have many enrolments, while each enrolment belongs to one student.

There is also a one-to-many relationship between courses and enrolments because one course can have many enrolments, while each enrolment belongs to one course.

Students and courses have a many-to-many relationship because one student can take many courses and one course can have many students. The `enrolments` table is needed as a join table to connect the two tables and store additional information such as the grade.

## Index

I would add an index on `enrolments.student_id` because it would make searches for a student's enrolments faster, especially when the database contains many enrolment records.

For example:

```sql
CREATE INDEX idx_enrolments_student_id
ON enrolments(student_id);
