# School Database Design

## Students Table

The `students` table stores information about each student. It contains the student's ID, name, and email address. The ID is the primary key, while the email address is UNIQUE so that two students cannot use the same email address.

## Courses Table

The `courses` table stores the courses offered by the school. Each course has an ID and a name. The ID is the primary key.

## Enrolments Table

The `enrolments` table records which students are enrolled in which courses. It contains foreign keys pointing to the students and courses tables. It also stores the student's grade for each course. A UNIQUE constraint on `student_id` and `course_id` prevents a student from enrolling in the same course twice.

## Relationships

There is a one-to-many relationship between students and enrolments because one student can have many enrolments, while each enrolment belongs to one student.

There is also a one-to-many relationship between courses and enrolments because one course can have many enrolments, while each enrolment belongs to one course.

Students and courses have a many-to-many relationship because one student can take many courses and one course can have many students. The `enrolments` table acts as a join table connecting students and courses. It is necessary to represent this relationship and store additional information, such as the grade for each enrolment.

## Index

I would add an index on `enrolments.student_id` because it can make searches for a student's enrolments faster, especially when the database contains many enrolment records.

For example:

```sql
CREATE INDEX idx_enrolments_student_id
ON enrolments(student_id);
```

## SQL or NoSQL?

I would choose SQL for this school management system because its data is structured and has clear relationships between students, courses, and enrolments. Relational databases use primary keys, foreign keys, and constraints to maintain data integrity and prevent invalid records, such as enrolments for students or courses that do not exist. SQL also supports JOINs, making it easier to retrieve students' courses, enrolment records, and grades. In addition, SQL databases support ACID transactions, which help ensure that related database changes are completed reliably and consistently. NoSQL databases, such as document stores, offer flexible data structures and can be useful when information has less predictable formats. However, maintaining relationships and consistency across separate documents may require additional application logic. Since a school system needs accurate enrolments, reliable grade updates, and consistent relationships between its data, I would choose a relational SQL database such as SQLite for this project.
